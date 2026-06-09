package com.carddraft.server.api;

import com.carddraft.server.service.DraftService;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/draft")
public class DraftController {
    private final DraftService draftService;

    public DraftController(DraftService draftService) {
        this.draftService = draftService;
    }

    @PostMapping("/start")
    public DraftService.DraftState startDraft(@RequestHeader("X-User-Id") UUID userId) {
        return draftService.startDraft(userId);
    }

    @GetMapping("/current")
    public DraftService.DraftState getCurrentDraft(@RequestHeader("X-User-Id") UUID userId) {
        return draftService.getDraft(userId);
    }

    @PostMapping("/pick")
    public DraftService.DraftState pickCard(
            @RequestHeader("X-User-Id") UUID userId,
            @RequestParam String cardId) {
        return draftService.pickCard(userId, cardId);
    }
}
