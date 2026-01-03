package com.example.demo;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI demoOpenApi() {
        SecurityScheme oidcScheme = new SecurityScheme()
                .name("cognito")
                .type(SecurityScheme.Type.OPENIDCONNECT)
                .openIdConnectUrl("/oauth2/idpresponse")
                .description("OIDC flow handled at the ALB layer");

        return new OpenAPI()
                .info(new Info()
                        .title("DevSecOps Demo API")
                        .version("1.0.0")
                        .description("REST endpoints exposed by the AWS-native DevSecOps demo application.")
                        .contact(new Contact().name("Platform Team")))
                .servers(List.of(
                        new Server().url("/").description("Relative base path via ALB")))
                .addSecurityItem(new SecurityRequirement().addList("cognito"))
                .components(new Components().addSecuritySchemes("cognito", oidcScheme));
    }
}
