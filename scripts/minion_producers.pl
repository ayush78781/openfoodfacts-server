#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Producers qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Nutriscore qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::MainCountries qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;

use Log::Any qw($log);
use Log::Log4perl;
Log::Log4perl->init("$conf_root/minion_log.conf");    # Init log4perl from a config file.
use Log::Any::Adapter;
Log::Any::Adapter->set('Log4perl');    # Send all logs to Log::Log4perl

use Mojolicious::Lite;

use Minion;

# Minion backend

$log->info("starting minion producers workers", {minion_backend => $server_options{minion_backend}}) if $log->is_info();

# load large data files into mod_perl memory
init_emb_codes();
init_packager_codes();
init_geocode_addresses();
init_packaging_taxonomies_regexps();

load_scans_data();

if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
	load_agribalyse_data();
	load_ecoscore_data();
	load_forest_footprint_data();
}

if (not defined $server_options{minion_backend}) {

	die("No Minion backend configured in lib/ProductOpener/Config2.pm\n");
}

plugin Minion => $server_options{minion_backend};

app->minion->add_task(import_csv_file => \&ProductOpener::Producers::import_csv_file_task);

app->minion->add_task(export_csv_file => \&ProductOpener::Producers::export_csv_file_task);

app->minion->add_task(
	update_export_status_for_csv_file => \&ProductOpener::Producers::update_export_status_for_csv_file_task);

app->minion->add_task(
	import_products_categories_from_public_database => \&import_products_categories_from_public_database_task);

app->config(
	hypnotoad => {
		listen => [$server_options{minion_daemon_server_and_port}],
		proxy => 1,
	},
);

app->start;

$log->info("minion producers workers stopped", {minion_backend => $server_options{minion_backend}}) if $log->is_info();
