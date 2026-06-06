package com.carddraft.server.api;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

public final class Dto {
    private Dto() {
    }

    public record GuestLoginRequest(String playerName) {
    }

    public record GuestLoginResponse(UUID userId) {
    }

    public record DeckSaveRequest(
            @NotBlank(message = "덱 이름이 필요합니다.") String name,
            @NotEmpty(message = "카드 목록이 필요합니다.") List<String> cardIds
    ) {
    }

    public record MatchCreateRequest(@NotBlank(message = "매치 모드가 필요합니다.") String mode, UUID deckId) {
    }

    public record MatchCreateResponse(UUID matchId, String mode, String opponentType, String opponentName) {
    }

    public record MatchResultRequest(@NotBlank(message = "전투 결과가 필요합니다.") String result) {
    }

    public record RewardResponse(
            String summary,
            int goldDelta,
            int rankDelta,
            String rewardCardId,
            String rewardCardName,
            Object profile,
            Map<String, Integer> collection
    ) {
    }
}
