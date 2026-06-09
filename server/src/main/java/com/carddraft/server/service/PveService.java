package com.carddraft.server.service;

import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class PveService {

    public static class PveState {
        public int currentFloor = 1;
        public int hp = 100;
        public int maxHp = 100;
        public List<String> relics = List.of();
        public String status = "in_progress"; // in_progress, dead, cleared
    }

    private final Map<UUID, PveState> activeRuns = new HashMap<>();

    public PveState startRun(UUID userId) {
        PveState state = new PveState();
        activeRuns.put(userId, state);
        return state;
    }

    public PveState getRun(UUID userId) {
        return activeRuns.get(userId);
    }

    public PveState progressFloor(UUID userId, boolean success, int hpLost) {
        PveState state = activeRuns.get(userId);
        if (state == null || !"in_progress".equals(state.status)) {
            throw new IllegalStateException("진행 중인 PvE 런이 없습니다.");
        }

        if (success) {
            state.currentFloor++;
            state.hp -= hpLost;
            if (state.hp <= 0) {
                state.hp = 0;
                state.status = "dead";
            } else if (state.currentFloor > 10) {
                state.status = "cleared";
            }
        } else {
            state.status = "dead";
        }
        return state;
    }
}
