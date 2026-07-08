defmodule Predictor.Guardrails.StakeLimits do
  @moduledoc """
  Applies bankroll guardrails to recommended stakes.

  Outputs are informational estimates only and are not guaranteed to produce a
  profit. This module never places bets.
  """

  @zero Decimal.new("0")

  def apply(recommended_stake, config, usage \\ %{}) do
    stake = decimal_value(recommended_stake)

    caps = [
      field(config, :per_bet_stake_cap),
      remaining(config, usage, :daily_stake_limit, :daily_staked),
      remaining(config, usage, :weekly_stake_limit, :weekly_staked),
      remaining(config, usage, :monthly_stake_limit, :monthly_staked)
    ]

    capped_stake = Enum.reduce(caps, stake, &decimal_min(decimal_value(&1), &2)) |> max_zero()

    if cooling_down?(config, usage) do
      %{recommended_stake: @zero, cooling_down?: true, uncapped_stake: stake}
    else
      %{recommended_stake: capped_stake, cooling_down?: false, uncapped_stake: stake}
    end
  end

  defp remaining(config, usage, limit_key, usage_key) do
    config
    |> field(limit_key)
    |> decimal_value()
    |> Decimal.sub(usage |> Map.get(usage_key, @zero) |> decimal_value())
    |> max_zero()
  end

  defp cooling_down?(config, usage) do
    loss_count = Map.get(usage, :consecutive_losses, 0)
    loss_threshold = field(config, :cooldown_after_loss_count) || 0
    cooldown_minutes = field(config, :cooldown_period_minutes) || 0

    loss_threshold > 0 and cooldown_minutes > 0 and loss_count >= loss_threshold
  end

  defp field(map, key) when is_map(map), do: Map.get(map, key)
  defp decimal_value(%Decimal{} = value), do: value
  defp decimal_value(nil), do: @zero
  defp decimal_value(value), do: Decimal.new(to_string(value))

  defp decimal_min(left, right) do
    case Decimal.compare(left, right) do
      :gt -> right
      _ -> left
    end
  end

  defp max_zero(value) do
    case Decimal.compare(value, @zero) do
      :lt -> @zero
      _ -> value
    end
  end
end
