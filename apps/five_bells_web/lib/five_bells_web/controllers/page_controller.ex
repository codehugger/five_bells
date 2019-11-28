defmodule FiveBellsWeb.PageController do
  use FiveBellsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
