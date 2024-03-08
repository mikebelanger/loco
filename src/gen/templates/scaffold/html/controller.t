{% set file_name = name |  snake_case -%}
{% set module_name = file_name | pascal_case -%}
to: src/controllers/{{ file_name }}.rs
skip_exists: true
message: "Controller `{{module_name}}` was added successfully."
injections:
- into: src/controllers/mod.rs
  append: true
  content: "pub mod {{ file_name }};"
- into: src/app.rs
  after: "AppRoutes::"
  content: "            .add_route(controllers::{{ file_name }}::routes())"
---
#![allow(clippy::missing_errors_doc)]
#![allow(clippy::unnecessary_struct_initialization)]
#![allow(clippy::unused_async)]
use loco_rs::prelude::*;
use serde::{Deserialize, Serialize};
use axum::{extract::Form, response::Redirect};
use sea_orm::{sea_query::Order, QueryOrder};

use crate::{
    models::_entities::{{file_name | plural}}::{ActiveModel, Column, Entity, Model},
    views,
};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Params {
    {% for column in columns -%}
    pub {{column.0}}: {{column.1}},
    {% endfor -%}
}

impl Params {
    fn update(&self, item: &mut ActiveModel) {
      {% for column in columns -%}
      item.{{column.0}} = Set(self.{{column.0}}.clone());
      {% endfor -%}
    }
}

async fn load_item(ctx: &AppContext, id: i32) -> Result<Model> {
    let item = Entity::find_by_id(id).one(&ctx.db).await?;
    item.ok_or_else(|| Error::NotFound)
}

pub async fn list(
    ViewEngine(v): ViewEngine<TeraView>,
    State(ctx): State<AppContext>,
) -> Result<Response> {
    let item = Entity::find()
        .order_by(Column::Id, Order::Desc)
        .all(&ctx.db)
        .await?;
    views::{{file_name}}::list(v, item)
}

pub async fn new(
    ViewEngine(v): ViewEngine<TeraView>,
    State(ctx): State<AppContext>,
) -> Result<Response> {
    views::{{file_name}}::create(v)
}

pub async fn update(
    Path(id): Path<i32>,
    State(ctx): State<AppContext>,
    Form(params): Form<Params>,
) -> Result<Redirect> {
    let item = load_item(&ctx, id).await?;
    let mut item = item.into_active_model();
    params.update(&mut item);
    item.update(&ctx.db).await?;
    Ok(Redirect::to("../{{file_name | plural}}"))
}

pub async fn edit(
    Path(id): Path<i32>,
    ViewEngine(v): ViewEngine<TeraView>,
    State(ctx): State<AppContext>,
) -> Result<Response> {
    let item = load_item(&ctx, id).await?;
    views::{{file_name}}::edit_form(v, item)
}

pub async fn show(
    Path(id): Path<i32>,
    ViewEngine(v): ViewEngine<TeraView>,
    State(ctx): State<AppContext>,
) -> Result<Response> {
    let item = load_item(&ctx, id).await?;
    views::{{file_name}}::show(v, item)
}

pub async fn add(
    ViewEngine(v): ViewEngine<TeraView>,
    State(ctx): State<AppContext>,
    Form(params): Form<Params>,
) -> Result<Redirect> {
    let mut item = ActiveModel {
        ..Default::default()
    };
    params.update(&mut item);
    item.insert(&ctx.db).await?;
    // views::post::show(v, item)
    Ok(Redirect::to("{{file_name | plural}}"))
}
pub fn routes() -> Routes {
    Routes::new()
        .prefix("{{file_name | plural}}")
        .add("/", get(list))
        .add("/new", get(new))
        .add("/:id", get(show))
        .add("/:id/edit", get(edit))
        .add("/:id", post(update))
        .add("/", post(add))
}
