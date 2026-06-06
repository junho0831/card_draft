package com.carddraft.server.api;

import java.util.Map;

import com.carddraft.server.model.ProfileView;
import com.carddraft.server.service.ProfileService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ProfileController {
    private final ProfileService profileService;

    public ProfileController(ProfileService profileService) {
        this.profileService = profileService;
    }

    @GetMapping("/profile")
    ProfileView profile(@RequestHeader("X-User-Id") String userId) {
        return profileService.profile(UserHeader.parse(userId));
    }

    @GetMapping("/collection")
    Map<String, Integer> collection(@RequestHeader("X-User-Id") String userId) {
        return profileService.collection(UserHeader.parse(userId));
    }
}
