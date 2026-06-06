package com.carddraft.server.api;

import java.util.List;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.repository.CardDraftRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/cards")
public class CardController {
    private final CardDraftRepository repository;

    public CardController(CardDraftRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    List<CardDefinition> cards() {
        return repository.findEnabledCards();
    }
}
