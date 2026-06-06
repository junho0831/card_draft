package com.carddraft.server.service;

import org.springframework.stereotype.Service;

@Service
public class RankService {
    public String rankName(int points) {
        if (points >= 2000) {
            return "다이아";
        }
        if (points >= 1500) {
            return "플래티넘";
        }
        if (points >= 1000) {
            return "골드";
        }
        if (points >= 500) {
            return "실버";
        }
        return "브론즈";
    }
}
