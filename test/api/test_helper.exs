# Load the main test helper which sets up everything properly
Code.require_file("../../test_helper.exs", __DIR__)

# Import API test helpers  
Code.require_file("support/api_case.ex", __DIR__)
# Load the ExMachina-Ash factory
Code.require_file("../support/factory.ex", __DIR__)
Code.require_file("../support/factory_helpers.ex", __DIR__)
