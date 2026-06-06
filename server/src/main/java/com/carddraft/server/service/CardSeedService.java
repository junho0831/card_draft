package com.carddraft.server.service;

import java.io.IOException;
import java.io.InputStream;

import com.carddraft.server.model.CardDefinition;
import com.carddraft.server.repository.CardDraftRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Service;

@Service
public class CardSeedService implements ApplicationRunner {
    private final CardDraftRepository repository;
    private final ObjectMapper objectMapper;

    public CardSeedService(CardDraftRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        seedCards();
    }

    public void seedCards() throws IOException {
        try (InputStream input = getClass().getResourceAsStream("/cards.json")) {
            if (input == null) {
                throw new IllegalStateException("cards.json 리소스를 찾을 수 없습니다.");
            }
            JsonNode cards = objectMapper.readTree(input);
            if (!cards.isArray()) {
                throw new IllegalStateException("cards.json은 배열이어야 합니다.");
            }
            for (JsonNode raw : cards) {
                repository.upsertCard(new CardDefinition(
                        requiredText(raw, "id"),
                        requiredText(raw, "name"),
                        requiredText(raw, "type"),
                        requiredText(raw, "race"),
                        requiredText(raw, "attr"),
                        raw.path("cost").asInt(),
                        raw.has("attack") ? raw.path("attack").asInt() : null,
                        raw.has("health") ? raw.path("health").asInt() : null,
                        raw.path("art").asInt(),
                        requiredText(raw, "text"),
                        raw.path("rarity").asText("일반"),
                        raw.path("enabled").asBoolean(true)
                ));
            }
        }
    }

    private String requiredText(JsonNode node, String field) {
        if (!node.hasNonNull(field) || node.path(field).asText().isBlank()) {
            throw new IllegalStateException("cards.json 필수 필드 누락: " + field);
        }
        return node.path(field).asText();
    }
}
