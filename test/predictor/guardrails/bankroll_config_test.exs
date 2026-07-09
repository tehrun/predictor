defmodule Predictor.Guardrails.BankrollConfigTest do
  use ExUnit.Case, async: true

  alias Predictor.Guardrails.BankrollConfig

  @valid_attrs %{
    bankroll_amount: "1000.00",
    currency: "USD",
    daily_stake_limit: "50.00",
    weekly_stake_limit: "200.00",
    monthly_stake_limit: "500.00",
    per_bet_stake_cap: "25.00",
    informational_only_acknowledged: true
  }

  test "requires explicit bankroll limits and informational-only acknowledgement" do
    changeset = BankrollConfig.changeset(%BankrollConfig{}, %{})

    refute changeset.valid?
    assert %{bankroll_amount: ["can't be blank"]} = errors_on(changeset)
    assert %{informational_only_acknowledged: [_]} = errors_on(changeset)
  end

  test "keeps automation disabled unless provider terms, legal review, and positive CLV are present" do
    changeset =
      BankrollConfig.changeset(
        %BankrollConfig{},
        Map.merge(@valid_attrs, %{
          bet_placement_automation_enabled: true,
          positive_clv_required: false
        })
      )

    refute changeset.valid?
    assert %{provider_terms_reviewed_at: ["can't be blank"]} = errors_on(changeset)
    assert %{jurisdiction_legal_reviewed_at: ["can't be blank"]} = errors_on(changeset)

    assert %{positive_clv_required: ["must remain enabled before bet placement automation"]} =
             errors_on(changeset)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
