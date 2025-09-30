package com.microsoft.migration.assets.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("message", "Asset Manager - Basic Version");
        model.addAttribute("status", "Database-only mode - Azure services disabled");
        return "home";
    }
    
    @GetMapping("/health")
    public String health(Model model) {
        model.addAttribute("status", "OK");
        model.addAttribute("message", "Application is running");
        return "health";
    }
}