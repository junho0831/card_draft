package com.carddraft.server.service;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.model.DeckRecord;
import com.carddraft.server.repository.CardDraftRepository;
import org.springframework.stereotype.Service;

@Service
public class DeckApplicationService {
    private final CardDraftRepository repository;
    private final ProfileService profileService;
    private final DeckValidator deckValidator;

    public DeckApplicationService(CardDraftRepository repository, ProfileService profileService, DeckValidator deckValidator) {
        this.repository = repository;
        this.profileService = profileService;
        this.deckValidator = deckValidator;
    }

    public List<DeckRecord> decks(UUID userId) {
        profileService.requireUser(userId);
        return repository.decks(userId);
    }

    public DeckRecord createDeck(UUID userId, String name, List<String> cardIds) {
        return saveDeck(userId, null, name, cardIds, true);
    }

    public DeckRecord updateDeck(UUID userId, UUID deckId, String name, List<String> cardIds) {
        return saveDeck(userId, deckId, name, cardIds, true);
    }

    public void selectDeck(UUID userId, UUID deckId) {
        profileService.requireUser(userId);
        repository.selectDeck(userId, deckId);
    }

    private DeckRecord saveDeck(UUID userId, UUID deckId, String name, List<String> cardIds, boolean selected) {
        profileService.requireUser(userId);
        List<CardDefinition> cards = repository.findEnabledCards();
        Set<String> known = cards.stream().map(CardDefinition::id).collect(Collectors.toSet());
        Map<String, Integer> owned = repository.collection(userId);
        Map<String, Integer> counts = deckValidator.validateAndCount(cardIds, known, owned);
        String deckName = name == null || name.isBlank() ? "내 덱" : name.trim();
        return repository.saveDeck(userId, deckId, deckName, counts, selected);
    }
}
