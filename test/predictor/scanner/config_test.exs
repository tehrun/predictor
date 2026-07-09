defmodule Predictor.Scanner.ConfigTest do
  use ExUnit.Case, async: false

  alias Predictor.Scanner.Config

  setup do
    previous = Application.get_env(:predictor, :scanner)

    on_exit(fn ->
      if previous do
        Application.put_env(:predictor, :scanner, previous)
      else
        Application.delete_env(:predictor, :scanner)
      end
    end)
  end

  test "loads defaults when scanner config is absent" do
    Application.delete_env(:predictor, :scanner)

    config = Config.load()

    assert config.enabled_sports == []
    assert config.enabled_leagues == []
    assert config.enabled_markets == []
    assert config.enabled_bookmakers == []
    assert config.sharp_reference_source == "pinnacle"
    assert Decimal.equal?(config.minimum_ev_threshold, Decimal.new("0.05"))
    assert Decimal.equal?(config.minimum_confidence_threshold, Decimal.new("0.50"))
    assert config.minimum_odds == nil
    assert config.maximum_odds == nil
    assert Decimal.equal?(config.kelly_fraction, Decimal.new("0.25"))
    assert Decimal.equal?(config.max_stake_percentage, Decimal.new("0.01"))
    assert Decimal.equal?(config.telegram_alert_threshold, Decimal.new("0.05"))
    assert config.odds_collection_frequency_seconds == 300
  end

  test "normalizes configured list and numeric values" do
    Application.put_env(:predictor, :scanner,
      enabled_sports: " Soccer,Football ",
      enabled_leagues: ["EPL", " la-liga "],
      enabled_markets: "h2h,spreads",
      enabled_bookmakers: ["Pinnacle", "bet365"],
      sharp_reference_source: "Circa",
      minimum_ev_threshold: "0.08",
      minimum_confidence_threshold: "0.65",
      minimum_odds: "1.80",
      maximum_odds: "5.00",
      kelly_fraction: "0.10",
      max_stake_percentage: "0.02",
      telegram_alert_threshold: "0.12",
      odds_collection_frequency_seconds: "120"
    )

    config = Config.load()

    assert config.enabled_sports == ["soccer", "football"]
    assert config.enabled_leagues == ["epl", "la-liga"]
    assert config.enabled_markets == ["h2h", "spreads"]
    assert config.enabled_bookmakers == ["pinnacle", "bet365"]
    assert config.sharp_reference_source == "Circa"
    assert Decimal.equal?(config.minimum_ev_threshold, Decimal.new("0.08"))
    assert Decimal.equal?(config.minimum_confidence_threshold, Decimal.new("0.65"))
    assert Decimal.equal?(config.minimum_odds, Decimal.new("1.80"))
    assert Decimal.equal?(config.maximum_odds, Decimal.new("5.00"))
    assert Decimal.equal?(config.kelly_fraction, Decimal.new("0.10"))
    assert Decimal.equal?(config.max_stake_percentage, Decimal.new("0.02"))
    assert Decimal.equal?(config.telegram_alert_threshold, Decimal.new("0.12"))
    assert config.odds_collection_frequency_seconds == 120
  end

  test "builds recommendation engine options" do
    Application.put_env(:predictor, :scanner,
      minimum_ev_threshold: "0.07",
      minimum_confidence_threshold: "0.60",
      minimum_odds: "1.50",
      maximum_odds: "4.50"
    )

    assert Config.load() |> Config.recommendation_opts() == [
             minimum_ev: Decimal.new("0.07"),
             minimum_odds: Decimal.new("1.50"),
             maximum_odds: Decimal.new("4.50"),
             confidence_score: Decimal.new("0.60")
           ]
  end

  test "enabled list treats empty lists as all enabled" do
    assert Config.enabled?([], "anything")
    assert Config.enabled?(["soccer"], " Soccer ")
    refute Config.enabled?(["soccer"], "basketball")
  end
end
