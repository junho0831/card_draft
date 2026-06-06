package com.carddraft.server.api;

import com.carddraft.server.service.ProfileService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class AuthController {
    private final ProfileService profileService;

    public AuthController(ProfileService profileService) {
        this.profileService = profileService;
    }

    @PostMapping("/guest-login")
    Dto.GuestLoginResponse guestLogin(@Valid @RequestBody(required = false) Dto.GuestLoginRequest request) {
        String playerName = request == null ? null : request.playerName();
        return new Dto.GuestLoginResponse(profileService.createGuest(playerName));
    }
}
