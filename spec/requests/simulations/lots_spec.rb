require "rails_helper"

RSpec.describe "Lots of a building", type: :request do
  let(:user) { create(:user) }
  let(:lots) do
    [{ "surface" => "40", "monthly_rent" => "500", "monthly_charges" => "50", "occupancy_months" => "12" },
     { "surface" => "60", "monthly_rent" => "700", "monthly_charges" => "100", "occupancy_months" => "9" }]
  end
  let(:simulation) { create(:simulation, user: user, property_type: "building", lots: lots) }

  before { sign_in user }

  describe "POST /simulations/:id/lots" do
    it "adds a lot of 50 m² at the rent proposed for 50 m²: 500 + 700 + 650 €" do
      post simulation_lots_path(simulation, tab: "parameters"), params: { lot: { surface: "50" } }, as: :turbo_stream

      expect(response.body).to include("Lot 3")
      expect(simulation.reload).to have_attributes(surface: 150, monthly_rent: 1_850, monthly_charges: 150)
      expect(simulation.lots.last.transform_values { |value| value.to_d })
        .to eq("surface" => 50, "monthly_rent" => 650, "monthly_charges" => 0, "occupancy_months" => 11)
    end

    it "refuses a lot without a surface and keeps the two others" do
      post simulation_lots_path(simulation), params: { lot: { surface: "" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(simulation.reload.lots).to eq(lots)
    end

    it "refuses a lot beyond the twentieth" do
      simulation.update!(lots: Array.new(Simulation::MAX_LOTS, lots.first))

      post simulation_lots_path(simulation), params: { lot: { surface: "50" } }, as: :turbo_stream

      expect(simulation.reload.lots.size).to eq(Simulation::MAX_LOTS)
    end
  end

  describe "DELETE /simulations/:id/lots/:index" do
    it "removes lot 1 and keeps lot 2: 700 € rent, 60 m²" do
      delete simulation_lot_path(simulation, 0, tab: "parameters"), as: :turbo_stream

      expect(response.body).to include("turbo-stream")
      expect(simulation.reload).to have_attributes(surface: 60, monthly_rent: 700, lots: [lots[1]])
    end

    it "keeps the last lot" do
      simulation.update!(lots: [lots.first])

      delete simulation_lot_path(simulation, 0), as: :turbo_stream

      expect(response).to have_http_status(:not_found)
      expect(simulation.reload.lots).to eq([lots.first])
    end

    it "finds no lot past the end of the list" do
      delete simulation_lot_path(simulation, 2), as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /simulations/:id" do
    it "offers to add a lot and to remove each one" do
      get simulation_path(simulation, tab: "parameters")

      doc = Nokogiri::HTML5(response.body)
      expect(doc.at_css("#panel-parameters .section-header form")["action"])
        .to eq(simulation_lots_path(simulation, tab: "parameters"))
      expect(doc.css("#panel-parameters tbody form.button_to").map { |form| form["action"] })
        .to eq([0, 1].map { |index| simulation_lot_path(simulation, index, tab: "parameters") })
    end

    it "offers no addition past the twentieth lot" do
      simulation.update!(lots: Array.new(Simulation::MAX_LOTS, lots.first))

      get simulation_path(simulation, tab: "parameters")

      expect(Nokogiri::HTML5(response.body).at_css("#panel-parameters .section-header form")).to be_nil
    end

    it "offers no removal of a single lot" do
      simulation.update!(lots: [lots.first])

      get simulation_path(simulation, tab: "parameters")

      expect(Nokogiri::HTML5(response.body).css("#panel-parameters tbody form.button_to")).to be_empty
    end
  end
end
