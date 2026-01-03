package com.example.demo;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;

@SpringBootTest
@AutoConfigureMockMvc
class HelloControllerTest {

    @Autowired
    private MockMvc mockMvc;
    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void rootEndpointReturnsGreeting() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        assertThat(response).contains("DevSecOps");
    }

    @Test
    void helloEndpointHandlesNullOidcHeader() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode node = mapper.readTree(response);
        assertThat(node.has("authenticatedUser")).isFalse();
    }

    @Test
    void helloEndpointHandlesEmptyOidcHeader() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .header("x-amzn-oidc-identity", "")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode node = mapper.readTree(response);
        assertThat(node.has("authenticatedUser")).isFalse();
    }

    @Test
    void helloEndpointIncludesValidOidcIdentity() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .header("x-amzn-oidc-identity", "user@example.com")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode node = mapper.readTree(response);
        assertThat(node.path("authenticatedUser").asText()).isEqualTo("user@example.com");
    }

    @Test
    void helloEndpointSanitizesOidcIdentity() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .header("x-amzn-oidc-identity", "user<>@example.com!!")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode node = mapper.readTree(response);
        assertThat(node.path("authenticatedUser").asText()).isEqualTo("user@example.com");
    }

    @Test
    void helloEndpointTimestampIsIso8601() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode node = mapper.readTree(response);
        Instant parsed = Instant.parse(node.path("timestamp").asText());
        assertThat(parsed).isNotNull();
    }

    @Test
    void helloEndpointReturnsExpectedStructure() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode node = mapper.readTree(response);
        assertThat(node.has("message")).isTrue();
        assertThat(node.has("timestamp")).isTrue();
        assertThat(node.path("message").asText()).contains("DevSecOps");
    }

    @Test
    void healthEndpointReturnsOk() throws Exception {
        String response = mockMvc.perform(MockMvcRequestBuilders.get("/healthz"))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andReturn().getResponse().getContentAsString();

        assertThat(response).isEqualTo("ok");
    }
}
