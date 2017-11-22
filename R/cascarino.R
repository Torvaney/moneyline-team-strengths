library(readr)
library(ggplot2)
library(dplyr)

# For aesthetic continuity
colours <- list(
  low = "#9ecae1",
  high = "#08519c"
)

simulations <- read_csv("data/cascarino_sims.csv")
strengths_eng <- read_csv("data/cascarino_England.csv") %>% mutate(country = "England")
strengths_sco <- read_csv("data/cascarino_Scotland.csv") %>% mutate(country = "Scotland")
strengths <- bind_rows(strengths_eng, strengths_sco)

teams_of_interest <- c("Man City", "Celtic")

# Plot ppg histograms ----
simulations %>% 
  mutate(played = ifelse(country == "Scotland", 44, 46),
         ppg = points / played) %>% 
  filter(team %in% teams_of_interest) %>% 
  ggplot(aes(x = ppg)) +
  # geom_histogram(aes(y = 100 * ..count.. / 1e4), 
  #                binwidth = 0.1, 
  #                fill = colours$high) +
  geom_density(aes(y = 10 * ..count.. / 1e4,
                   fill = team),
               colour = NA,
               alpha = 0.8) +
  # facet_wrap( ~ team) +
  scale_fill_manual(values = c(Celtic = "forestgreen", `Man City` = "skyblue")) +
  theme_minimal() +
  theme(legend.position = "bottom",
        legend.title = element_blank()) +
  ggtitle("Simulated points per game", 
          "2017/18") +
  xlab("PPG") +
  ylab("%")


strengths %>% 
  filter(season == 2017) %>% 
  ggplot(aes(x = reorder(team, strength), y = strength)) +
  # geom_point(aes()) +
  geom_segment(aes(y = lower, yend = upper,
                   xend = reorder(team, strength))) +
  facet_wrap( ~ country, scales = "free_y") +
  coord_flip()

# Trivia ----
simulations %>% 
  filter(team %in% teams_of_interest) %>% 
  group_by(team, lose == 0) %>% 
  summarise(n = n()) %>% 
  group_by(team) %>% 
  mutate(p = n / sum(n))

simulations %>% 
  filter(team %in% teams_of_interest) %>% 
  group_by(team, lose == 0 & draw == 0) %>% 
  summarise(n = n()) %>% 
  group_by(team) %>% 
  mutate(p = n / sum(n))


# Sandbox ----
simulations %>% 
  group_by(country, team, points) %>% 
  summarise(n = n()) %>% 
  group_by(team) %>% 
  mutate(percent = n / sum(n)) %>% 
  ggplot(aes(x = points, y = reorder(team, points))) +
  geom_tile(aes(alpha = percent), fill = colours$high) +
  facet_wrap( ~ country, scales = "free_y") +
  scale_alpha(range = c(0, 1)) +
  theme_minimal() +
  theme(legend.position = "None") +
  ggtitle("Projected points", 
          "2017/18") +
  xlab("") +
  ylab("")

simulations %>% 
  group_by(country, team, points) %>% 
  summarise(n = n()) %>% 
  group_by(team) %>% 
  mutate(percent = n / sum(n)) %>% 
  ungroup() %>% 
  mutate(played = ifelse(country == "England", 46, 22))


simulations %>% 
  group_by(country, team) %>% 
  summarise(points = mean(points),
            win = mean(win),
            draw = mean(draw),
            lose = mean(lose)) %>% 
  mutate(played = ifelse(country == "Scotland", 22, 46),
         ppg = points / played,
         win_pc = win / played,
         draw_pc = draw / played,
         lose_pc = lose / played) %>% 
  arrange(desc(points)) %>% 
  slice(1)
