package com.carddraft.server.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.stereotype.Service;

@Service
public class DeckValidator {
    public static final int DECK_SIZE = 30;
    public static final int MAX_COPIES = 3;

    public Map<String, Integer> validateAndCount(
            List<String> cardIds,
            Set<String> knownCardIds,
            Map<String, Integer> ownedCards
    ) {
        if (cardIds == null || cardIds.size() != DECK_SIZE) {
            throw new IllegalArgumentException("덱은 정확히 30장이어야 합니다.");
        }
        Map<String, Integer> counts = new HashMap<>();
        for (String cardId : cardIds) {
            if (cardId == null || cardId.isBlank() || !knownCardIds.contains(cardId)) {
                throw new IllegalArgumentException("알 수 없는 카드가 있습니다.");
            }
            int nextCount = counts.getOrDefault(cardId, 0) + 1;
            if (nextCount > MAX_COPIES) {
                throw new IllegalArgumentException("동일 카드는 최대 3장까지 넣을 수 있습니다.");
            }
            if (nextCount > ownedCards.getOrDefault(cardId, 0)) {
                throw new IllegalArgumentException("보유 수량보다 많은 카드를 넣을 수 없습니다.");
            }
            counts.put(cardId, nextCount);
        }
        return counts;
    }
}
