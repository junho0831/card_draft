package com.carddraft.server.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class RewardRulesTest {
    private final RewardRules rewardRules = new RewardRules();

    @Test
    void casualWinGrantsGoldAndCardWithoutRankChange() {
        RewardRules.RewardDelta delta = rewardRules.calculate("casual", "win");

        assertThat(delta.goldDelta()).isEqualTo(30);
        assertThat(delta.rankDelta()).isZero();
        assertThat(delta.grantCard()).isTrue();
    }

    @Test
    void rankedLossLosesRankPointsAndDoesNotGrantCard() {
        RewardRules.RewardDelta delta = rewardRules.calculate("ranked", "loss");

        assertThat(delta.goldDelta()).isEqualTo(10);
        assertThat(delta.rankDelta()).isEqualTo(-10);
        assertThat(delta.grantCard()).isFalse();
    }
}
