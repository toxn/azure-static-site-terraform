# Offline tests. No Azure subscription, no credentials, no network calls to Azure.
#
# `mock_provider` swaps the real provider for a fake one that returns generated
# values for computed attributes. That means the entire module graph can be
# planned and asserted on a laptop, which is exactly what CI runs on every push.
#
# Run with:  terraform -chdir=infra test        (or: make test)

mock_provider "azurerm" {
  mock_resource "azurerm_static_web_app" {
    # override_during = plan makes the fake values available during `plan`,
    # so assertions can compare them instead of seeing "known after apply".
    override_during = plan

    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo/providers/Microsoft.Web/staticSites/swa-demo-prod-abcde"
      default_host_name = "swa-demo-prod-abcde.azurestaticapps.net"
      api_key           = "mock-deployment-token"
    }
  }
}

mock_provider "random" {
  mock_resource "random_string" {
    override_during = plan
    defaults = {
      result = "abcde"
    }
  }
}

# ---------------------------------------------------------------------------
# Defaults: Free tier, no custom domain, predictable naming.
# ---------------------------------------------------------------------------
run "plans_a_free_static_web_app_by_default" {
  command = plan

  variables {
    project             = "demo"
    environment         = "prod"
    resource_group_name = "rg-demo"
  }

  assert {
    condition     = output.site_url == "https://swa-demo-prod-abcde.azurestaticapps.net"
    error_message = "site_url should be the HTTPS URL of the Static Web App default host name."
  }

  assert {
    condition     = startswith(output.static_web_app_name, "swa-demo-prod-")
    error_message = "the app name should follow swa-<project>-<environment>-<suffix>."
  }

  assert {
    condition     = output.custom_domain_url == null
    error_message = "custom_domain_url should be null when no custom domain is configured."
  }

  assert {
    condition     = output.resource_group_name == "rg-demo"
    error_message = "resource_group_name should fall back to rg-<project>."
  }
}

# ---------------------------------------------------------------------------
# Naming is derived, so a different environment must not collide.
# ---------------------------------------------------------------------------
run "derives_the_name_from_project_and_environment" {
  command = plan

  variables {
    project             = "shop"
    environment         = "staging"
    resource_group_name = "rg-shop"
  }

  assert {
    condition     = startswith(output.static_web_app_name, "swa-shop-staging-")
    error_message = "changing project/environment must change the resource name."
  }
}

# ---------------------------------------------------------------------------
# Optional custom domain is wired through to the module and the output.
# ---------------------------------------------------------------------------
run "attaches_a_custom_domain_when_asked" {
  command = plan

  variables {
    custom_domain                 = "www.example.com"
    custom_domain_validation_type = "cname-delegation"
  }

  assert {
    condition     = output.custom_domain_url == "https://www.example.com"
    error_message = "custom_domain_url should reflect the configured domain."
  }
}

# ---------------------------------------------------------------------------
# Guard rails: the variable validations must reject bad input.
# ---------------------------------------------------------------------------
run "rejects_an_unknown_sku_tier" {
  command = plan

  variables {
    sku_tier = "enterprise"
  }

  expect_failures = [var.sku_tier]
}

run "rejects_a_project_name_with_uppercase" {
  command = plan

  variables {
    project = "MyApp"
  }

  expect_failures = [var.project]
}
