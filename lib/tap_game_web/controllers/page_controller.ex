defmodule TapGameWeb.PageController do
  use TapGameWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
