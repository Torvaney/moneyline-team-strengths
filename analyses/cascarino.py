import os

import numpy as np
import pandas as pd

import model
import project_season


def extract_team_strength_dict(team_strengths):
    """ Parse team strength dataframe into a dict mapping teamname: strength. """
    indexed_strengths = team_strengths.set_index('team')

    # Only take ratings from this season
    indexed_strengths = indexed_strengths.loc[lambda df: df['season'] == 2017]

    # Just use median strength estimate for now.
    # Could sample from the Stan fitted samples later on if we wanted?
    strength_map = indexed_strengths['strength'].to_dict()
    return strength_map


if __name__ == '__main__':
    # Load data for Scottish and English league clusters
    games = pd.read_csv(os.path.join(os.path.dirname(__file__), 'data/cascarino.csv'))

    # Fit the model on each league cluster
    games_scotland = games.loc[lambda df: df['country'] == 'Scotland']
    fit_scotland = model.run_stan_model(games_scotland)
    strengths_scotland = model.parse_stan_fit(fit_scotland, games_scotland)
    strengths_scotland = extract_team_strength_dict(strengths_scotland)

    games_england = games.loc[lambda df: df['country'] == 'England']
    fit_england = model.run_stan_model(games_england)
    strengths_england = model.parse_stan_fit(fit_england, games_england)
    strengths_england = extract_team_strength_dict(strengths_england)

    n_sims = int(1e4)
    empty_games = pd.DataFrame([], columns=['home_team', 'away_team'])
    empty_games = empty_games.set_index(['home_team', 'away_team'])

    # Simulate Celtic's season
    sim_scotland = project_season.simulate_seasons(
        n_sims,
        empty_games,
        strengths_scotland,
        np.median(fit_scotland['home_theta']),
        np.median(fit_scotland['away_theta'])
    )
    sim_scotland['country'] = 'Scotland'

    # Simulate Man City in League 1
    filtered_games = games.loc[lambda df: df['competition'] == "League One"]
    filtered_teams = set(filtered_games['home_team']) | set(filtered_games['away_team']) | {'Man City'}
    strengths_filtered = {k: v for k, v in strengths_england.items() if k in filtered_teams}

    # Remove the weakest team to make the 'league' have the right number of teams
    weakest_team = min(strengths_filtered, key=strengths_filtered.get)
    strengths_filtered.pop(weakest_team)

    sim_england = project_season.simulate_seasons(
        n_sims,
        empty_games,
        strengths_filtered,
        np.median(fit_england['home_theta']),
        np.median(fit_england['away_theta'])
    )
    sim_england['country'] = 'England'

    # Output simulations to csv
    combined_sim = pd.concat([sim_scotland, sim_england])
    combined_sim.to_csv(
        os.path.join(os.path.dirname(__file__), 'data/cascarino_sims.csv'),
        index=False, encoding='utf-8'
    )
