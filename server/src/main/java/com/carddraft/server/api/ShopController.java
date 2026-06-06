package com.carddraft.server.api;

import java.util.List;

import com.carddraft.server.service.ShopService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/shop")
public class ShopController {
    private final ShopService shopService;

    public ShopController(ShopService shopService) {
        this.shopService = shopService;
    }

    @GetMapping("/products")
    List<Dto.ShopProductResponse> products() {
        return shopService.products();
    }

    @PostMapping("/purchase")
    Dto.ShopPurchaseResponse purchase(
            @RequestHeader("X-User-Id") String userId,
            @Valid @RequestBody Dto.ShopPurchaseRequest request
    ) {
        return shopService.purchase(UserHeader.parse(userId), request.productId(), request.raceFilter());
    }
}
