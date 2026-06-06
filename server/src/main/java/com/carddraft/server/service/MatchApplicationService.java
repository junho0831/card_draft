package com.carddraft.server.service;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.carddraft.server.api.Dto;
import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.repository.CardDraftRepository;
import com.carddraft.server.service.RewardRules.RewardDelta;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MatchApplicationService {
    private final CardDraftRepository repository;
    private final ProfileService profileService;
    private final RewardRules rewardRules;
    private final StringRedisTemplate redisTemplate;

    public MatchApplicationService(
            CardDraftRepository repository,
            ProfileService profileService,
            RewardRules rewardRules,
            StringRedisTemplate redisTemplate
    ) {
        this.repository = repository;
        this.profileService = profileService;
        this.rewardRules = rewardRules;
        this.redisTemplate = redisTemplate;
    }

    public Dto.MatchCreateResponse createAiMatch(UUID userId, String mode, UUID deckId) {
        profileService.requireUser(userId);
        if (!"casual".equals(mode) && !"ranked".equals(mode)) {
            throw new IllegalArgumentException("매치 모드는 casual 또는 ranked만 가능합니다.");
        }
        if (deckId == null) {
            deckId = profileService.profile(userId).selectedDeckId();
        }
        if (deckId == null || repository.deck(userId, deckId).isEmpty()) {
            throw new IllegalArgumentException("선택된 덱을 찾을 수 없습니다.");
        }
        UUID matchId = repository.createMatch(userId, mode, "ai");
        try {
            redisTemplate.opsForValue().set("matchmaking:" + userId, matchId.toString(), Duration.ofSeconds(30));
        } catch (RuntimeException ex) {
            // Redis는 MVP 매칭 연출용이다. Redis 장애가 매치 생성을 막지는 않는다.
        }
        return new Dto.MatchCreateResponse(matchId, mode, "ai", "AI 상대");
    }

    @Transactional
    public Dto.RewardResponse submitResult(UUID userId, UUID matchId, String result) {
        profileService.requireUser(userId);
        if (!"win".equals(result) && !"loss".equals(result)) {
            throw new IllegalArgumentException("전투 결과는 win 또는 loss만 가능합니다.");
        }
        var match = repository.pendingMatch(userId, matchId);
        RewardDelta delta = rewardRules.calculate(match.mode(), result);
        String rewardCardId = null;
        String rewardCardName = null;
        if (delta.grantCard()) {
            List<CardDefinition> cards = repository.findEnabledCards();
            if (!cards.isEmpty()) {
                CardDefinition card = cards.get((int) (Math.random() * cards.size()));
                rewardCardId = card.id();
                rewardCardName = card.name();
                repository.incrementOwnedCard(userId, rewardCardId, 1);
            }
        }
        repository.applyProfileDelta(userId, delta.goldDelta(), delta.rankDelta());
        repository.completeMatch(matchId, delta.goldDelta(), delta.rankDelta(), result, rewardCardId);
        String summary = summary(match.mode(), result, delta.goldDelta(), delta.rankDelta(), rewardCardName);
        return new Dto.RewardResponse(
                summary,
                delta.goldDelta(),
                delta.rankDelta(),
                rewardCardId,
                rewardCardName,
                profileService.profile(userId),
                profileService.collection(userId)
        );
    }

    private String summary(String mode, String result, int goldDelta, int rankDelta, String rewardCardName) {
        String modeName = "ranked".equals(mode) ? "랭크전" : "일반전";
        String resultName = "win".equals(result) ? "승리" : "패배";
        StringBuilder builder = new StringBuilder()
                .append(modeName).append(' ').append(resultName).append('\n')
                .append("골드 +").append(goldDelta).append('\n');
        if ("ranked".equals(mode)) {
            builder.append("랭크 점수 ");
            if (rankDelta >= 0) {
                builder.append('+');
            }
            builder.append(rankDelta).append('\n');
        }
        if (rewardCardName != null) {
            builder.append("카드 획득: ").append(rewardCardName).append('\n');
        }
        return builder.toString();
    }
}
