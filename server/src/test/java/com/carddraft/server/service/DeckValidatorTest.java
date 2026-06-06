package com.carddraft.server.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.junit.jupiter.api.Test;

class DeckValidatorTest {
    private final DeckValidator validator = new DeckValidator();

    @Test
    void validatesThirtyCardsWithMaxThreeCopiesAndOwnedQuantity() {
        List<String> deck = validDeck();

        Map<String, Integer> counts = validator.validateAndCount(deck, knownCards(), ownedCards());

        assertThat(counts.values()).allMatch(count -> count <= 3);
        assertThat(counts.values().stream().mapToInt(Integer::intValue).sum()).isEqualTo(30);
    }

    @Test
    void rejectsShortDeck() {
        assertThatThrownBy(() -> validator.validateAndCount(List.of("card_0"), knownCards(), ownedCards()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("30장");
    }

    @Test
    void rejectsFourthCopy() {
        List<String> deck = validDeck();
        deck.set(3, "card_0");

        assertThatThrownBy(() -> validator.validateAndCount(deck, knownCards(), ownedCards()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("최대 3장");
    }

    @Test
    void rejectsOverOwnedCard() {
        List<String> deck = validDeck();
        Map<String, Integer> owned = ownedCards();
        owned.put("card_0", 1);

        assertThatThrownBy(() -> validator.validateAndCount(deck, knownCards(), owned))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("보유 수량");
    }

    private List<String> validDeck() {
        List<String> deck = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            deck.add("card_" + i);
            deck.add("card_" + i);
            deck.add("card_" + i);
        }
        return deck;
    }

    private Set<String> knownCards() {
        return Set.of("card_0", "card_1", "card_2", "card_3", "card_4", "card_5", "card_6", "card_7", "card_8", "card_9");
    }

    private Map<String, Integer> ownedCards() {
        return new java.util.HashMap<>(Map.of(
                "card_0", 3,
                "card_1", 3,
                "card_2", 3,
                "card_3", 3,
                "card_4", 3,
                "card_5", 3,
                "card_6", 3,
                "card_7", 3,
                "card_8", 3,
                "card_9", 3
        ));
    }
}
