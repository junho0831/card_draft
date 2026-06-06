package com.carddraft.server.api;

import java.util.List;
import java.util.UUID;

import com.carddraft.server.model.DeckRecord;
import com.carddraft.server.service.DeckApplicationService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/decks")
public class DeckController {
    private final DeckApplicationService deckService;

    public DeckController(DeckApplicationService deckService) {
        this.deckService = deckService;
    }

    @GetMapping
    List<DeckRecord> decks(@RequestHeader("X-User-Id") String userId) {
        return deckService.decks(UserHeader.parse(userId));
    }

    @PostMapping
    DeckRecord createDeck(@RequestHeader("X-User-Id") String userId, @Valid @RequestBody Dto.DeckSaveRequest request) {
        return deckService.createDeck(UserHeader.parse(userId), request.name(), request.cardIds());
    }

    @PutMapping("/{deckId}")
    DeckRecord updateDeck(
            @RequestHeader("X-User-Id") String userId,
            @PathVariable UUID deckId,
            @Valid @RequestBody Dto.DeckSaveRequest request
    ) {
        return deckService.updateDeck(UserHeader.parse(userId), deckId, request.name(), request.cardIds());
    }

    @PostMapping("/{deckId}/select")
    void selectDeck(@RequestHeader("X-User-Id") String userId, @PathVariable UUID deckId) {
        deckService.selectDeck(UserHeader.parse(userId), deckId);
    }
}
