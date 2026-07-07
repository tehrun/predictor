defmodule Predictor.Notifications.Telegram do
  @moduledoc "Telegram alert configuration and delivery boundary."

  def configured? do
    config = Application.get_env(:predictor, :external_apis, [])
    config[:telegram_bot_token] not in [nil, ""] and config[:telegram_chat_id] not in [nil, ""]
  end
end
