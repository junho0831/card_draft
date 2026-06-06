package com.carddraft.server.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.model.DeckRecord;
import com.carddraft.server.model.ProfileView;
import com.carddraft.server.service.RankService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
public class CardDraftRepository {
    private final JdbcTemplate jdbc;
    private final RankService rankService;

    public CardDraftRepository(JdbcTemplate jdbc, RankService rankService) {
        this.jdbc = jdbc;
        this.rankService = rankService;
    }

    public void upsertCard(CardDefinition card) {
        jdbc.update("""
                insert into cards (id, name, type, race, attr, cost, attack, health, art, text, rarity, enabled)
                values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                on conflict (id) do update set
                    name = excluded.name,
                    type = excluded.type,
                    race = excluded.race,
                    attr = excluded.attr,
                    cost = excluded.cost,
                    attack = excluded.attack,
                    health = excluded.health,
                    art = excluded.art,
                    text = excluded.text,
                    rarity = excluded.rarity,
                    enabled = excluded.enabled
                """,
                card.id(), card.name(), card.type(), card.race(), card.attr(), card.cost(), card.attack(),
                card.health(), card.art(), card.text(), card.rarity(), card.enabled());
    }

    public List<CardDefinition> findEnabledCards() {
        return jdbc.query("""
                select id, name, type, race, attr, cost, attack, health, art, text, rarity, enabled
                from cards
                where enabled = true
                order by cost, name
                """, this::mapCard);
    }

    public Optional<CardDefinition> findCard(String cardId) {
        return jdbc.query("""
                select id, name, type, race, attr, cost, attack, health, art, text, rarity, enabled
                from cards
                where id = ?
                """, this::mapCard, cardId).stream().findFirst();
    }

    public UUID createUser(String playerName) {
        UUID userId = UUID.randomUUID();
        jdbc.update("insert into users (id, player_name, gold, rank_points) values (?, ?, 0, 0)", userId, playerName);
        return userId;
    }

    public boolean userExists(UUID userId) {
        Integer count = jdbc.queryForObject("select count(*) from users where id = ?", Integer.class, userId);
        return count != null && count > 0;
    }

    public ProfileView profile(UUID userId) {
        return jdbc.query("""
                select u.id, u.player_name, u.gold, u.rank_points,
                       coalesce(sum(uc.quantity), 0) as owned_card_count,
                       (select d.id from decks d where d.user_id = u.id and d.is_selected = true limit 1) as selected_deck_id
                from users u
                left join user_cards uc on uc.user_id = u.id
                where u.id = ?
                group by u.id
                """, rs -> {
            if (!rs.next()) {
                throw new IllegalArgumentException("유저를 찾을 수 없습니다.");
            }
            int points = rs.getInt("rank_points");
            return new ProfileView(
                    rs.getObject("id", UUID.class),
                    rs.getString("player_name"),
                    rs.getInt("gold"),
                    points,
                    rankService.rankName(points),
                    rs.getInt("owned_card_count"),
                    (UUID) rs.getObject("selected_deck_id")
            );
        }, userId);
    }

    public Map<String, Integer> collection(UUID userId) {
        Map<String, Integer> result = new LinkedHashMap<>();
        jdbc.query("""
                select c.id, coalesce(uc.quantity, 0) as quantity
                from cards c
                left join user_cards uc on uc.card_id = c.id and uc.user_id = ?
                where c.enabled = true
                order by c.cost, c.name
                """, rs -> {
            result.put(rs.getString("id"), rs.getInt("quantity"));
        }, userId);
        return result;
    }

    public void upsertOwnedCard(UUID userId, String cardId, int quantity) {
        jdbc.update("""
                insert into user_cards (user_id, card_id, quantity)
                values (?, ?, ?)
                on conflict (user_id, card_id) do update set quantity = excluded.quantity
                """, userId, cardId, quantity);
    }

    public void incrementOwnedCard(UUID userId, String cardId, int delta) {
        jdbc.update("""
                insert into user_cards (user_id, card_id, quantity)
                values (?, ?, ?)
                on conflict (user_id, card_id) do update set quantity = user_cards.quantity + excluded.quantity
                """, userId, cardId, delta);
    }

    public boolean debitGoldIfEnough(UUID userId, int price) {
        int updated = jdbc.update("""
                update users
                set gold = gold - ?,
                    updated_at = now()
                where id = ? and gold >= ?
                """, price, userId, price);
        return updated > 0;
    }

    @Transactional
    public DeckRecord saveDeck(UUID userId, UUID deckId, String name, Map<String, Integer> counts, boolean selected) {
        UUID id = deckId == null ? UUID.randomUUID() : deckId;
        if (deckId == null) {
            jdbc.update("insert into decks (id, user_id, name, is_selected) values (?, ?, ?, false)", id, userId, name);
        } else {
            int updated = jdbc.update("update decks set name = ?, updated_at = now() where id = ? and user_id = ?", name, id, userId);
            if (updated == 0) {
                throw new IllegalArgumentException("덱을 찾을 수 없습니다.");
            }
            jdbc.update("delete from deck_cards where deck_id = ?", id);
        }
        for (Map.Entry<String, Integer> entry : counts.entrySet()) {
            jdbc.update("insert into deck_cards (deck_id, card_id, quantity) values (?, ?, ?)",
                    id, entry.getKey(), entry.getValue());
        }
        if (selected) {
            selectDeck(userId, id);
        }
        return deck(userId, id).orElseThrow();
    }

    @Transactional
    public void selectDeck(UUID userId, UUID deckId) {
        Integer exists = jdbc.queryForObject("select count(*) from decks where id = ? and user_id = ?", Integer.class, deckId, userId);
        if (exists == null || exists == 0) {
            throw new IllegalArgumentException("덱을 찾을 수 없습니다.");
        }
        jdbc.update("update decks set is_selected = false where user_id = ?", userId);
        jdbc.update("update decks set is_selected = true, updated_at = now() where id = ? and user_id = ?", deckId, userId);
    }

    public Optional<DeckRecord> deck(UUID userId, UUID deckId) {
        List<DeckRecord> decks = jdbc.query("""
                select id, name, is_selected
                from decks
                where user_id = ? and id = ?
                """, (rs, rowNum) -> mapDeckHeader(rs), userId, deckId);
        return decks.stream().findFirst();
    }

    public List<DeckRecord> decks(UUID userId) {
        return jdbc.query("""
                select id, name, is_selected
                from decks
                where user_id = ?
                order by is_selected desc, updated_at desc
                """, (rs, rowNum) -> mapDeckHeader(rs), userId);
    }

    public UUID createMatch(UUID userId, String mode, String opponentType) {
        UUID matchId = UUID.randomUUID();
        jdbc.update("""
                insert into matches (id, user_id, mode, opponent_type)
                values (?, ?, ?, ?)
                """, matchId, userId, mode, opponentType);
        return matchId;
    }

    public MatchRow pendingMatch(UUID userId, UUID matchId) {
        return jdbc.query("""
                select id, user_id, mode, opponent_type, result
                from matches
                where id = ? and user_id = ?
                """, rs -> {
            if (!rs.next()) {
                throw new IllegalArgumentException("매치를 찾을 수 없습니다.");
            }
            if (!"pending".equals(rs.getString("result"))) {
                throw new IllegalStateException("이미 완료된 매치입니다.");
            }
            return new MatchRow(
                    rs.getObject("id", UUID.class),
                    rs.getObject("user_id", UUID.class),
                    rs.getString("mode"),
                    rs.getString("opponent_type"),
                    rs.getString("result")
            );
        }, matchId, userId);
    }

    @Transactional
    public void completeMatch(UUID matchId, int goldDelta, int rankDelta, String result, String rewardCardId) {
        jdbc.update("""
                update matches
                set result = ?, gold_delta = ?, rank_delta = ?, reward_card_id = ?, completed_at = ?
                where id = ?
                """, result, goldDelta, rankDelta, rewardCardId, Timestamp.from(Instant.now()), matchId);
    }

    @Transactional
    public void applyProfileDelta(UUID userId, int goldDelta, int rankDelta) {
        jdbc.update("""
                update users
                set gold = gold + ?,
                    rank_points = greatest(0, rank_points + ?),
                    updated_at = now()
                where id = ?
                """, goldDelta, rankDelta, userId);
    }

    private CardDefinition mapCard(ResultSet rs, int rowNum) throws SQLException {
        return new CardDefinition(
                rs.getString("id"),
                rs.getString("name"),
                rs.getString("type"),
                rs.getString("race"),
                rs.getString("attr"),
                rs.getInt("cost"),
                (Integer) rs.getObject("attack"),
                (Integer) rs.getObject("health"),
                rs.getInt("art"),
                rs.getString("text"),
                rs.getString("rarity"),
                rs.getBoolean("enabled")
        );
    }

    private DeckRecord mapDeckHeader(ResultSet rs) throws SQLException {
        UUID deckId = rs.getObject("id", UUID.class);
        List<String> cardIds = new ArrayList<>();
        jdbc.query("""
                select card_id, quantity
                from deck_cards
                where deck_id = ?
                order by card_id
                """, deckRs -> {
            for (int i = 0; i < deckRs.getInt("quantity"); i++) {
                cardIds.add(deckRs.getString("card_id"));
            }
        }, deckId);
        return new DeckRecord(deckId, rs.getString("name"), rs.getBoolean("is_selected"), cardIds);
    }

    public record MatchRow(UUID id, UUID userId, String mode, String opponentType, String result) {
    }
}
