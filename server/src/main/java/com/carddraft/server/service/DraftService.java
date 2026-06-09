package com.carddraft.server.service;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.repository.CardDraftRepository;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class DraftService {
    private final CardDraftRepository repository;
    private final Random random = new Random();
    
    // In-memory draft state (prototype)
    private final Map<UUID, DraftState> activeDrafts = new HashMap<>();

    public static class DraftState {
        public List<String> deck = new ArrayList<>();
        public List<CardDefinition> currentChoices = new ArrayList<>();
        public int wins = 0;
        public int losses = 0;
        public boolean isFinished = false;
    }

    public DraftService(CardDraftRepository repository) {
        this.repository = repository;
    }

    public DraftState startDraft(UUID userId) {
        DraftState state = new DraftState();
        activeDrafts.put(userId, state);
        rollChoices(state);
        return state;
    }

    public DraftState getDraft(UUID userId) {
        return activeDrafts.get(userId);
    }

    public DraftState pickCard(UUID userId, String cardId) {
        DraftState state = activeDrafts.get(userId);
        if (state == null || state.isFinished) {
            throw new IllegalStateException("진행 중인 드래프트가 없습니다.");
        }
        
        boolean validChoice = state.currentChoices.stream().anyMatch(c -> c.id().equals(cardId));
        if (!validChoice) {
            throw new IllegalArgumentException("유효하지 않은 카드 선택입니다.");
        }

        state.deck.add(cardId);
        state.currentChoices.clear();
        
        if (state.deck.size() < 30) {
            rollChoices(state);
        }
        
        return state;
    }

    private void rollChoices(DraftState state) {
        List<CardDefinition> allCards = repository.findEnabledCards();
        Collections.shuffle(allCards, random);
        state.currentChoices = allCards.subList(0, Math.min(3, allCards.size()));
    }
}
