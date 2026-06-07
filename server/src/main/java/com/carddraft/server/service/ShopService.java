package com.carddraft.server.service;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import com.carddraft.server.api.Dto;
import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.repository.CardDraftRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ShopService {
    private static final List<Product> PRODUCTS = List.of(
            new Product("apprentice_pack", "견습 카드 팩", 50, 1, false,
                    "가볍게 카드 풀을 넓히는 기본 팩",
                    List.of("전체 카드 풀에서 랜덤 카드 1장", "종족 제한 없음")),
            new Product("race_pack", "종족 지원 팩", 80, 1, true,
                    "선택한 종족 카드만 노리는 전용 팩",
                    List.of("선택 종족 카드 중 랜덤 1장", "인간 / 엘프 / 언데드 중 선택")),
            new Product("battle_pack", "전장 보급 팩", 120, 3, false,
                    "빠르게 덱 재료를 모으는 3장 팩",
                    List.of("전체 카드 풀에서 랜덤 카드 3장", "중복 획득 가능"))
    );

    private final CardDraftRepository repository;
    private final ProfileService profileService;

    public ShopService(CardDraftRepository repository, ProfileService profileService) {
        this.repository = repository;
        this.profileService = profileService;
    }

    public List<Dto.ShopProductResponse> products() {
        return PRODUCTS.stream()
                .map(product -> new Dto.ShopProductResponse(
                        product.id(),
                        product.name(),
                        product.price(),
                        product.cardCount(),
                        product.raceSelectable(),
                        product.description(),
                        product.contents()
                ))
                .toList();
    }

    @Transactional
    public Dto.ShopPurchaseResponse purchase(UUID userId, String productId, String raceFilter) {
        profileService.requireUser(userId);
        Product product = findProduct(productId);
        List<CardDefinition> pool = cardPool(product, raceFilter);
        if (pool.isEmpty()) {
            throw new IllegalArgumentException("선택한 조건에 맞는 카드가 없습니다.");
        }
        if (!repository.debitGoldIfEnough(userId, product.price())) {
            throw new IllegalArgumentException("골드가 부족합니다.");
        }

        List<Dto.ShopCardResponse> gainedCards = new ArrayList<>();
        for (int i = 0; i < product.cardCount(); i++) {
            CardDefinition card = pool.get(ThreadLocalRandom.current().nextInt(pool.size()));
            repository.incrementOwnedCard(userId, card.id(), 1);
            gainedCards.add(new Dto.ShopCardResponse(card.id(), card.name()));
        }

        return new Dto.ShopPurchaseResponse(
                summary(product, gainedCards),
                -product.price(),
                gainedCards,
                profileService.profile(userId),
                profileService.collection(userId)
        );
    }

    private Product findProduct(String productId) {
        return PRODUCTS.stream()
                .filter(product -> product.id().equals(productId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("알 수 없는 상품입니다."));
    }

    private List<CardDefinition> cardPool(Product product, String raceFilter) {
        List<CardDefinition> cards = repository.findEnabledCards();
        if (!product.raceSelectable()) {
            return cards;
        }
        String race = raceFilter == null ? "" : raceFilter.trim();
        return cards.stream()
                .filter(card -> card.race().equals(race))
                .toList();
    }

    private String summary(Product product, List<Dto.ShopCardResponse> cards) {
        String cardNames = cards.stream()
                .map(Dto.ShopCardResponse::name)
                .reduce((left, right) -> left + ", " + right)
                .orElse("");
        return "%s 구매\n골드 -%d\n카드 획득: %s\n".formatted(product.name(), product.price(), cardNames);
    }

    private record Product(
            String id,
            String name,
            int price,
            int cardCount,
            boolean raceSelectable,
            String description,
            List<String> contents
    ) {
    }
}
