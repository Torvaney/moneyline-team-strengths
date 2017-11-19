import argparse
import os

import numpy as np
import pandas as pd
import progressbar
import pystan

import model


def calculate_probabilities(home_strength, away_strength, home_theta, away_theta):
    home_prob = model.logistic(home_theta + (home_strength - away_strength))
    away_prob = model.logistic(away_theta - (home_strength - away_strength))
    draw_prob = 1 - (home_prob + away_prob)
    return home_prob, draw_prob, away_prob


def simulate_game(home_prob, draw_prob, away_prob):
    """ Simulates a single game, returning home and away points. """

    probs = [home_prob, draw_prob, away_prob]

    home_points = np.random.choice([3, 1, 0], p=probs)
    if home_points == 3:
        away_points = 0
    elif home_points == 1:
        away_points = 1
    elif home_points == 0:
        away_points = 3

    return home_points, away_points


def simulate_season(games, team_strengths, home_theta, away_theta):
    """
    Simulates a season once from a dataframe of games already played and a set
    of model parameters:
     * team_strength: dict of team name: strength
     * home_theta: model's home intercept
     * away_theta: model's away intercept
    """
    team_map = model.get_team_map(games)

    # Make specific fixtures easy to retreive
    indexed_games = games.set_index(['home_team', 'away_team'])

    # Initialise teams' points to zero
    team_points = {t: 0 for t in team_map}
    for home_team in team_map:
        for away_team in team_map:
            if home_team == away_team:
                # A team cannot play itself, ignore this
                continue
            try:
                # Try to fetch game from those already played
                game = indexed_games.loc[home_team, away_team]
            except KeyError:
                # Game has not been played; simulate game instead
                probs = calculate_probabilities(
                    team_strengths[home_team],
                    team_strengths[away_team],
                    home_theta,
                    away_theta
                )
                home_points, away_points = simulate_game(*probs)
                game = {
                    'home_points': home_points,
                    'away_points': away_points
                }

            team_points[home_team] += game['home_points']
            team_points[away_team] += game['away_points']
    return team_points


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('gamesfile', help='Location of csv containing existing games.')
    parser.add_argument('outfile', help='Where to save the simulated seasons.')
    args = parser.parse_args()

    # Load the data
    games = pd.read_csv(args.gamesfile)

    # Wrangle the data and fit the model
    games = model.prepare_games(games)
    fit = model.run_stan_model(games)

    # Parse the output into a nice dict
    team_map = model.get_team_map(games)
    team_strengths = {
        name: fit['team_strength'][i-1] for name, i in team_map.items()
    }

    # Now simulate the season using model estimates
    n_sims = int(1e4)
    pbar = progressbar.ProgressBar(max_value=n_sims)
    simulated_seasons = []
    for sim_id in range(n_sims):
        simulation = simulate_season(
            games,
            team_strengths,
            fit['theta_home'],
            fit['theta_away']
        )

        # Store individual records tidily
        for team, pts in simulation.items():
            simulated_seasons.append({
                'team': team,
                'points': pts,
                'sim_id': sim_id + 1
            })
        pbar += 1
    pbar.finish()

    # Dump simulation results to file
    simulated_seasons = pd.DataFrame(simulated_seasons)
    simulated_seasons.to_csv(args.outfile, index=False, encoding='utf-8')
