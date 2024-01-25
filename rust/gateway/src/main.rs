use crate::eventloop::{Eventloop, PHOENIX_TOPIC};
use crate::messages::InitGateway;
use anyhow::{Context, Result};
use backoff::ExponentialBackoffBuilder;
use boringtun::x25519::StaticSecret;
use clap::Parser;
use connlib_shared::{get_user_agent, login_url, Callbacks, Mode};
use firezone_cli_utils::{setup_global_subscriber, CommonArgs};
use firezone_tunnel::{GatewayState, Tunnel};
use futures::{future, TryFutureExt};
use phoenix_channel::SecureUrl;
use secrecy::{Secret, SecretString};
use std::convert::Infallible;
use std::path::Path;
use std::pin::pin;
use std::sync::Arc;
use tokio::io::AsyncWriteExt;
use tokio::signal::ctrl_c;
use tracing_subscriber::layer;
use url::Url;
use uuid::Uuid;

mod eventloop;
mod messages;

const ID_PATH: &str = "/var/lib/firezone/gateway_id";

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    setup_global_subscriber(layer::Identity::new());

    let firezone_id = get_firezone_id(cli.firezone_id).await
        .context("Couldn't read FIREZONE_ID or write it to disk: Please provide it through the env variable or provide rw access to /var/lib/firezone/")?;
    let (connect_url, private_key) = login_url(
        Mode::Gateway,
        cli.common.api_url,
        SecretString::new(cli.common.token),
        firezone_id,
        cli.common.firezone_name,
    )?;

    let task = tokio::spawn(run(connect_url, private_key)).err_into();

    let ctrl_c = pin!(ctrl_c().map_err(anyhow::Error::new));

    match future::try_select(task, ctrl_c)
        .await
        .map_err(|e| e.factor_first().0)?
    {
        future::Either::Left((res, _)) => {
            res?;
        }
        future::Either::Right(_) => {}
    };

    Ok(())
}

async fn get_firezone_id(env_id: Option<String>) -> Result<String> {
    if let Some(id) = env_id {
        if !id.is_empty() {
            return Ok(id);
        }
    }

    if let Ok(id) = tokio::fs::read_to_string(ID_PATH).await {
        if !id.is_empty() {
            return Ok(id);
        }
    }

    let id_path = Path::new(ID_PATH);
    tokio::fs::create_dir_all(id_path.parent().unwrap()).await?;
    let mut id_file = tokio::fs::File::create(id_path).await?;
    let id = Uuid::new_v4().to_string();
    id_file.write_all(id.as_bytes()).await?;
    Ok(id)
}

async fn run(connect_url: Url, private_key: StaticSecret) -> Result<Infallible> {
    let tunnel: Arc<Tunnel<_, GatewayState>> =
        Arc::new(Tunnel::new(private_key, CallbackHandler).await?);

    let (portal, init) = phoenix_channel::init::<_, InitGateway, _, _>(
        Secret::new(SecureUrl::from_url(connect_url.clone())),
        get_user_agent(None),
        PHOENIX_TOPIC,
        (),
        ExponentialBackoffBuilder::default()
            .with_max_elapsed_time(None)
            .build(),
    )
    .await??;

    tunnel
        .set_interface(&init.interface)
        .context("Failed to set interface")?;

    let mut eventloop = Eventloop::new(tunnel, portal);

    future::poll_fn(|cx| eventloop.poll(cx))
        .await
        .context("Eventloop failed")?;

    unreachable!()
}

#[derive(Clone)]
struct CallbackHandler;

impl Callbacks for CallbackHandler {
    type Error = Infallible;
}

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(flatten)]
    common: CommonArgs,
    /// Identifier generated by the portal to identify and display the device.
    #[arg(short = 'i', long, env = "FIREZONE_ID")]
    pub firezone_id: Option<String>,
}
