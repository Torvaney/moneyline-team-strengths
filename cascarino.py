import logging
import os
import sys

import numpy as np
import pandas as pd

import model
import project_season

logging.basicConfig(stream=sys.stdout, level=logging.INFO)
log = logging.Logger(__name__)


def extract_team_strength_dict(team_strengths):
    """ Parse team strength dataframe into a dict mapping teamname: strength. """
    indexed_strengths = team_strengths.set_index('team')

    # Make sure we get the latest rating
    indexed_strengths = indexed_strengths.loc[lambda df: df['season'] == 2017]

    # Just use median strength estimate for now.
    # Could sample from the Stan fitted samples later on if we wanted?
    strength_map = indexed_strengths['strength'].to_dict()
    return strength_map


if __name__ == '__main__':
    # Load data for Scottish and English league clusters
    log.info('Loading data')
    games = pd.read_csv(os.path.join(os.path.dirname(__file__), 'data/cascarino.csv'))
    games = model.prepare_games(games)

    n_sims = int(1e4)
    empty_games = pd.DataFrame([], columns=['home_team', 'away_team'])

    sims = {}
    for country in ('England', 'Scotland'):
        log.info('Estimating strengths for country: {}'.format(country))
        country_games = games.loc[lambda df: df['country'] == country]
        fit = model.run_stan_model(country_games)
        strengths = model.parse_stan_fit(fit, country_games)
        latest_strengths = extract_team_strength_dict(strengths)

        log.info('Saving strength estimates')
        strengths.to_csv(os.path.join(
            os.path.dirname(__file__),
            'data/cascarino_{}.csv'.format(country)),
            index=False, encoding='utf-8'
        )

        log.info('Finding participating teams')
        if country == 'Scotland':
            filtered_games = games.query('country == "Scotland" & season == 2017')
            filtered_teams = set(filtered_games['home_team']) | set(filtered_games['away_team'])
        if country == 'England':
            filtered_games = games.query('competition == "League One" & season == 2017')
            filtered_teams = set(filtered_games['home_team']) | set(filtered_games['away_team']) | {'Man City'}

        filtered_strengths = {k: v for k, v in latest_strengths.items() if k in filtered_teams}

        if country == 'England':
            # Remove the weakest team to make the 'league' have the right number of teams
            weakest_team = min(filtered_strengths, key=filtered_strengths.get)
            filtered_strengths.pop(weakest_team)

        log.info('Simulating league for country: {}'.format(country))
        sims[country] = project_season.simulate_seasons(
            n_sims,
            empty_games,
            filtered_strengths,
            np.median(fit['theta_home']),
            np.median(fit['theta_away']),
            cycles=2 if country == 'Scotland' else 1
        )
        sims[country]['country'] = country

    log.info('Saving simulated seasons')
    combined_sim = pd.concat(list(sims.values()))
    combined_sim.to_csv(
        os.path.join(os.path.dirname(__file__), 'data/cascarino_sims.csv'),
        index=False, encoding='utf-8'
    )
