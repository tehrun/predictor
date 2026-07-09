defmodule Predictor.Guardrails.StakeLimitsTest do
  use ExUnit.Case, async: true

  alias Predictor.Guardrails.StakeLimits

  @config %{
    per_bet_stake_cap: Decimal.new("25.00"),
    daily_stake_limit: Decimal.new("50.00"),
    weekly_stake_limit: Decimal.new("100.00"),
    monthly_stake_limit: Decimal.new("300.00"),
    cooldown_after_loss_count: 3,
    cooldown_period_minutes: 60
  }

  test "caps recommendation by per-bet and period remaining limits" do
    result =
      StakeLimits.apply("80.00", @config, %{
        daily_staked: "30.00",
        weekly_staked: "90.00",
        monthly_staked: "100.00"
      })

    assert Decimal.equal?(result.recommended_stake, Decimal.new("10.00"))
    refute result.cooling_down?
  end

  test "suppresses recommendations during configured loss cooldown" do
    result = StakeLimits.apply("20.00", @config, %{consecutive_losses: 3})

    assert Decimal.equal?(result.recommended_stake, Decimal.new("0"))
    assert result.cooling_down?
  end
end
