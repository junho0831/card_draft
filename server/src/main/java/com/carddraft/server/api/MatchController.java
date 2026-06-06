package com.carddraft.server.api;

import java.util.UUID;

import com.carddraft.server.service.MatchApplicationService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/matches")
public class MatchController {
    private final MatchApplicationService matchService;

    public MatchController(MatchApplicationService matchService) {
        this.matchService = matchService;
    }

    @PostMapping("/ai")
    Dto.MatchCreateResponse createAiMatch(
            @RequestHeader("X-User-Id") String userId,
            @Valid @RequestBody Dto.MatchCreateRequest request
    ) {
        return matchService.createAiMatch(UserHeader.parse(userId), request.mode(), request.deckId());
    }

    @PostMapping("/{matchId}/result")
    Dto.RewardResponse submitResult(
            @RequestHeader("X-User-Id") String userId,
            @PathVariable UUID matchId,
            @Valid @RequestBody Dto.MatchResultRequest request
    ) {
        return matchService.submitResult(UserHeader.parse(userId), matchId, request.result());
    }
}
