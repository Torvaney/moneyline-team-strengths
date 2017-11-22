import argparse
import collections
import os

import numpy as np
import pandas as pd
import progressbar
import pystan

import model


Sim = collections.namedtuple('Sim', 'team points win draw lose sim_id')


class TeamRecord(object):
    __slots__ = ('points', 'win', 'draw', 'lose')

    def __init__(self):
        self.points = 0
        self.win = 0
        self.draw = 0
        self.lose = 0


def calculate_probabilities(home_strength, away_strength, home_theta, away_theta):
    home_prob = model.logistic(home_theta + (home_strength - away_strength))
    away_prob = model.logistic(away_theta - (home_strength - away_strength))
    draw_prob = 1 - (home_prob + away_prob)
    return home_prob, draw_prob, away_prob


def simulate_game(home_prob, draw_prob, away_prob):
    """ Simulates a single game, returning home and away points. """

    probs = [home_prob, draw_prob, away_prob]
    result = np.random.choice(['H', 'D', 'A'], p=probs)
    return result


def simulate_season_once(games, team_strengths, home_theta, away_theta, cycles=1):
    """
    Simulates a season once from a dataframe of games already played and a set
    of model parameters:
     * team_strength: dict of team name: strength
     * home_theta: model's home intercept
     * away_theta: model's away intercept
    """
    teams = set(team_strengths)

    # Make specific fixtures easy to retreive
    indexed_games = games.set_index(['home_team', 'away_team'])

    # Initialise teams' points to zero
    team_points = {t: TeamRecord() for t in teams}
    for _ in range(cycles):
        for home_team in teams:
            for away_team in teams:
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
                    result = simulate_game(*probs)

                if result == 'H':
                    team_points[home_team].points += 3
                    team_points[away_team].points += 0
                    team_points[home_team].win += 1
                    team_points[away_team].lose += 1
                elif result == 'D':
                    team_points[home_team].points += 1
                    team_points[away_team].points += 1
                    team_points[home_team].draw += 1
                    team_points[away_team].draw += 1
                elif result == 'A':
                    team_points[home_team].points += 0
                    team_points[away_team].points += 3
                    team_points[home_team].lose += 1
                    team_points[away_team].win += 1

    return team_points


def simulate_seasons(n_sims, games, team_strengths, home_theta, away_theta, cycles=1):
    """
    Simulates a season `n_sims` times from a dataframe of games already played
    and a set of model parameters:
     * team_strength: dict of team name: strength
     * home_theta: model's home intercept
     * away_theta: model's away intercept
    """
    pbar = progressbar.ProgressBar(max_value=n_sims)
    simulated_seasons = []
    for sim_id in range(n_sims):
        simulation = simulate_season_once(
            games,
            team_strengths,
            home_theta,
            away_theta,
            cycles
        )

        # Store individual records tidily
        for team, record in simulation.items():
            simulated_seasons.append(Sim(
                team=team,
                points=record.points,
                win=record.win,
                draw=record.draw,
                lose=record.lose,
                sim_id=sim_id + 1
            ))
        pbar += 1
    pbar.finish()
    return pd.DataFrame(simulated_seasons)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('gamesfile', help='Location of csv containing existing games.')
    parser.add_argument('outfile', help='Where to save the simulated seasons.')
    parser.add_argument('--n_sims', type=int, default=int(1e4),
                        help='Number of times to simulate the season')
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
    simulated_seasons = simulate_seasons(
        args.n_sims,
        games,
        team_strengths,
        fit['theta_home'],
        fit['theta_away']
    )
    # Dump simulation results to file
    simulated_seasons.to_csv(args.outfile, index=False, encoding='utf-8')
