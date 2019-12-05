defmodule Recipe do
  defstruct product_name: "Recipe Product",
            components: []

  def produce(%Recipe{} = recipe), do: %Product{name: recipe.product_name}
end
