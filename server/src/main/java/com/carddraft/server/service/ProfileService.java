package com.carddraft.server.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.model.DeckRecord;
import com.carddraft.server.model.ProfileView;
import com.carddraft.server.repository.CardDraftRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProfileService {
    private final CardDraftRepository repository;
    private final DeckValidator deckValidator;

    public ProfileService(CardDraftRepository repository, DeckValidator deckValidator) {
        this.repository = repository;
        this.deckValidator = deckValidator;
    }

    @Transactional
    public UUID createGuest(String playerName) {
        String name = playerName == null || playerName.isBlank() ? "플레이어" : playerName.trim();
        UUID userId = repository.createUser(name);
        List<CardDefinition> cards = repository.findEnabledCards();
        Map<String, Integer> owned = initialCollection(cards);
        owned.forEach((cardId, quantity) -> repository.upsertOwnedCard(userId, cardId, quantity));
        List<String> starterDeck = starterDeck(cards, owned);
        Set<String> known = cards.stream().map(CardDefinition::id).collect(Collectors.toSet());
        Map<String, Integer> counts = deckValidator.validateAndCount(starterDeck, known, owned);
        repository.saveDeck(userId, null, "스타터 덱", counts, true);
        return userId;
    }

    public void requireUser(UUID userId) {
        if (userId == null || !repository.userExists(userId)) {
            throw new IllegalArgumentException("유저를 찾을 수 없습니다.");
        }
    }

    public ProfileView profile(UUID userId) {
        requireUser(userId);
        return repository.profile(userId);
    }

    public Map<String, Integer> collection(UUID userId) {
        requireUser(userId);
        return repository.collection(userId);
    }

    private Map<String, Integer> initialCollection(List<CardDefinition> cards) {
        Map<String, Integer> owned = new LinkedHashMap<>();
        for (int i = 0; i < cards.size(); i++) {
            owned.put(cards.get(i).id(), i < 6 ? 3 : 2);
        }
        return owned;
    }

    private List<String> starterDeck(List<CardDefinition> cards, Map<String, Integer> owned) {
        return cards.stream()
                .flatMap(card -> java.util.stream.IntStream.range(0, Math.min(owned.getOrDefault(card.id(), 0), DeckValidator.MAX_COPIES))
                        .mapToObj(i -> card.id()))
                .limit(DeckValidator.DECK_SIZE)
                .toList();
    }
}
