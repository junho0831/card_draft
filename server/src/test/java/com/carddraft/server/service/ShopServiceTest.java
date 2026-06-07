package com.carddraft.server.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.model.ProfileView;
import com.carddraft.server.repository.CardDraftRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ShopServiceTest {
    private final CardDraftRepository repository = mock(CardDraftRepository.class);
    private final ProfileService profileService = mock(ProfileService.class);
    private final UUID userId = UUID.randomUUID();
    private ShopService shopService;

    @BeforeEach
    void setUp() {
        shopService = new ShopService(repository, profileService);
        when(repository.findEnabledCards()).thenReturn(List.of(
                card("flame_swordsman", "불꽃 검사", "인간"),
                card("forest_archer", "숲의 궁수", "엘프"),
                card("grave_knight", "무덤 기사", "언데드")
        ));
        when(profileService.profile(userId)).thenReturn(new ProfileView(userId, "플레이어", 50, 0, "브론즈", 31, null));
        when(profileService.collection(userId)).thenReturn(Map.of("flame_swordsman", 4));
    }

    @Test
    void returnsShopProducts() {
        assertThat(shopService.products())
                .extracting("id")
                .containsExactly("apprentice_pack", "race_pack", "battle_pack");
    }

    @Test
    void purchasesRandomCardWhenGoldIsEnough() {
        when(repository.debitGoldIfEnough(userId, 50)).thenReturn(true);

        var response = shopService.purchase(userId, "apprentice_pack", "");

        assertThat(response.goldDelta()).isEqualTo(-50);
        assertThat(response.cards()).hasSize(1);
        verify(repository).incrementOwnedCard(eq(userId), any(), eq(1));
    }

    @Test
    void purchasesRaceCardOnlyFromSelectedRace() {
        when(repository.debitGoldIfEnough(userId, 80)).thenReturn(true);

        var response = shopService.purchase(userId, "race_pack", "엘프");

        assertThat(response.cards()).hasSize(1);
        assertThat(response.cards().getFirst().id()).isEqualTo("forest_archer");
        verify(repository).incrementOwnedCard(userId, "forest_archer", 1);
    }

    @Test
    void rejectsPurchaseWhenGoldIsNotEnough() {
        when(repository.debitGoldIfEnough(userId, 120)).thenReturn(false);

        assertThatThrownBy(() -> shopService.purchase(userId, "battle_pack", ""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("골드");

        verify(repository, never()).incrementOwnedCard(eq(userId), any(), eq(1));
    }

    @Test
    void rejectsUnknownProduct() {
        assertThatThrownBy(() -> shopService.purchase(userId, "unknown", ""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("알 수 없는 상품");
    }

    private CardDefinition card(String id, String name, String race) {
        return new CardDefinition(id, name, "unit", race, "화염", 1, 1, 1, 0, "테스트 카드", "일반", true);
    }
}
