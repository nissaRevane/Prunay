# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_01_01_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "simulations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "purchase_date", null: false
    t.decimal "purchase_price", precision: 12, scale: 2, null: false
    t.decimal "monthly_rent", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "property_type", default: "apartment", null: false
    t.string "address"
    t.string "city", default: "", null: false
    t.string "energy_rating"
    t.decimal "surface", precision: 8, scale: 2, null: false
    t.boolean "condominium", default: false, null: false
    t.decimal "initial_works", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "occupancy_months", precision: 4, scale: 1, default: "11.0", null: false
    t.string "rental_type", default: "furnished", null: false
    t.decimal "property_tax", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "maintenance", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "insurance", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "other_charges", precision: 12, scale: 2, default: "0.0", null: false
    t.string "name", default: "", null: false
    t.decimal "condominium_fees", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "management_fees", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "rent_guarantee", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "business_tax", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "accounting_fees", precision: 12, scale: 2, default: "0.0", null: false
    t.index ["user_id", "purchase_date"], name: "index_simulations_on_user_id_and_purchase_date"
    t.index ["user_id"], name: "index_simulations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "firstname", default: "", null: false
    t.string "lastname", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "simulations", "users"
end
