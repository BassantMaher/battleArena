defmodule TapGame.Accounts do
  @moduledoc """
  The Accounts context for managing users.
  """

  import Ecto.Query, warn: false
  alias TapGame.Repo
  alias TapGame.Accounts.User

  @doc """
  Gets a single user by id.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Creates a user or gets existing user by username.
  """
  def get_or_create_user(attrs \\ %{}) do
    case get_user_by_username(attrs["username"] || attrs[:username]) do
      nil -> create_user(attrs)
      user -> {:ok, user}
    end
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end
end
