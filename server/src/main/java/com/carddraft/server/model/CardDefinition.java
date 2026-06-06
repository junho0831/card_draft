package com.carddraft.server.model;

public record CardDefinition(
        String id,
        String name,
        String type,
        String race,
        String attr,
        int cost,
        Integer attack,
        Integer health,
        int art,
        String text,
        String rarity,
        boolean enabled
) {
}
