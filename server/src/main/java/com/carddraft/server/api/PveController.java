package com.carddraft.server.api;

import com.carddraft.server.service.PveService;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/pve")
public class PveController {
    private final PveService pveService;

    public PveController(PveService pveService) {
        this.pveService = pveService;
    }

    @PostMapping("/start")
    public PveService.PveState startRun(@RequestHeader("X-User-Id") UUID userId) {
        return pveService.startRun(userId);
    }

    @GetMapping("/current")
    public PveService.PveState getCurrentRun(@RequestHeader("X-User-Id") UUID userId) {
        return pveService.getRun(userId);
    }

    @PostMapping("/progress")
    public PveService.PveState progressFloor(
            @RequestHeader("X-User-Id") UUID userId,
            @RequestParam boolean success,
            @RequestParam(defaultValue = "0") int hpLost) {
        return pveService.progressFloor(userId, success, hpLost);
    }
}
