defmodule Recipe do
  defstruct product_name: "Recipe Product",
            components: [],
            ttl: -1

  def produce(%Recipe{components: components} = recipe) when length(components) == 0 do
    %Product{name: recipe.product_name, ttl: recipe.ttl}
  end

  def requires_components?(%Recipe{} = recipe), do: length(recipe.components) > 0
  def ininite_ttl?(%Recipe{} = recipe), do: recipe.ttl <= 0
end
