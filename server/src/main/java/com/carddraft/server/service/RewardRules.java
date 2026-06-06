package com.carddraft.server.service;

import org.springframework.stereotype.Service;

@Service
public class RewardRules {
    public RewardDelta calculate(String mode, String result) {
        boolean win = "win".equals(result);
        if ("ranked".equals(mode)) {
            return win ? new RewardDelta(20, 25, true) : new RewardDelta(10, -10, false);
        }
        if ("casual".equals(mode)) {
            return win ? new RewardDelta(30, 0, true) : new RewardDelta(10, 0, false);
        }
        throw new IllegalArgumentException("알 수 없는 매치 모드입니다.");
    }

    public record RewardDelta(int goldDelta, int rankDelta, boolean grantCard) {
    }
}
