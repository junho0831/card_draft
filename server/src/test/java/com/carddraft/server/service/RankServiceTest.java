package com.carddraft.server.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class RankServiceTest {
    private final RankService rankService = new RankService();

    @Test
    void returnsRankNameByPointRange() {
        assertThat(rankService.rankName(0)).isEqualTo("브론즈");
        assertThat(rankService.rankName(500)).isEqualTo("실버");
        assertThat(rankService.rankName(1000)).isEqualTo("골드");
        assertThat(rankService.rankName(1500)).isEqualTo("플래티넘");
        assertThat(rankService.rankName(2000)).isEqualTo("다이아");
    }
}
