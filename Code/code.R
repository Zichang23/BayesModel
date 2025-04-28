#read in data
library(readxl)
mydata <- read.csv("imputed.csv", header = T)

#calculate expected unemployment count
unemploy <- c(0.096, 0.089, 0.081, 0.074, 0.062, 0.053, 0.049, 0.044, 0.039, 0.037, 0.081, 0.053, 0.036)
avg.unemploy <- mean(unemploy)
mydata$E <- mydata$Population*avg.unemploy
mydata$Y <- round(mydata$Population*mydata$Unemployment*0.01)

#calculate SUR (standard unemployment rate)
mydata$SUR <- mydata$Y/mydata$E
mydata[,4] <- NULL

#standardize the dataset
library(dplyr)
mydata[,5:10] <- mydata[,5:10] %>% mutate_all(~(scale(.) %>% as.vector))
mydata1 <- mydata[which(!(mydata$State %in% c("Alaska", "Hawaii", "Puerto Rico"))),c("State","Year", "Y", "E", "GDP", "Consumption","Jobs", "SUR")]

#merge count and ID
library(readxl)
mydata2 <- read_excel("1.xlsx", sheet = 1, col_names=T)
dmerge <- merge(mydata1, mydata2, by.x = "State")

#read in spatial data for US
library(raster)
States <- raster::getData("GADM", country = "United States", level = 1)

#remove two states for convenient of view
States <- States[States$NAME_1 != "Alaska" & States$NAME_1 != "Hawaii",]
map <- States

#take data from 2010
d2010 <- dmerge[which(dmerge$Year=='2010'),]
rownames(d2010) <- d2010$ID

#check state and ID relationship in the spatial data
sapply(slot(map, "polygons"), function(x){slot(x, "ID")}) 

#merge spatial, outcome, and covariates together
library(sp)
map1 <- SpatialPolygonsDataFrame(map, d2010, match.ID = TRUE)

#plot SUR in 2010
library(leaflet)
l <- leaflet(map1) %>% addTiles()
pal <- colorNumeric(palette = "YlOrRd", domain = map1$SUR)
l %>%
  addPolygons(
    color = "grey", weight = 1,
    fillColor = ~ pal(SUR), fillOpacity = 0.5
  ) %>%
  addLegend(
    pal = pal, values = ~SUR, opacity = 0.5,
    title = "SUR", position = "bottomright"
  )

## Linear trends in each state
mydata3 <- mydata[which(!(mydata$State %in% c("Puerto Rico"))),c("State","Year", "Y", "E", "GDP", "Consumption","Jobs","SUR")]

#read in ID info in the order in the spatial data
mydata4 <- read_excel("1.xlsx", sheet = 2, col_names=T)
dmerge2 <- merge(mydata3, mydata4, by.x = "State")

#read in spatial data for US
States2 <- raster::getData("GADM", country = "United States", level = 1)
map2 <- States2

#time plots of SURs
library(ggplot2)
g <- ggplot(dmerge2, aes(x = Year, y = SUR, 
                         group = State, color = State)) +
  geom_line() + geom_point(size = 2) + theme_bw() + theme(legend.position = "none")
g

#highlight one state
library(gghighlight)
g + gghighlight(State == "Texas")

#modeling
dw <- reshape(dmerge2,timevar = "Year",idvar = "State",direction = "wide")
dw[1:2, ]
map2@data[1:2, ]
map3 <- merge(map2, dw, by.x = "NAME_1", by.y = "State")
map3@data[1:2, ]

#mapping SURs (not done)
library(sf)
map_sf <- st_as_sf(map3)
library(tidyr)
year <- 2010:2022
map_sf <- gather(map_sf, year, SUR, paste0("SUR.", 2010:2022))
map_sf$year <- as.integer(substring(map_sf$Year, 5, 8))
library(ggplot2)
ggplot(map_sf) + geom_sf(aes(fill = SUR)) +
  facet_wrap(~year, dir = "h", ncol = 7) +
  ggtitle("SUR") + theme_bw() +
  theme(
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks = element_blank()
  ) +
  scale_fill_gradient2(
    midpoint = 1, low = "blue", mid = "white", high = "red"
  )
library(spdep)
nb <- poly2nb(map3)

#check spatial correlation
lw <- nb2listw(nb, style="W", zero.policy=TRUE)
MC<- moran.mc(map3$SUR.2010, lw, nsim = 999, alternative = "greater", zero.policy=TRUE)
MC
library(INLA)
nb2INLA("map.adj", nb)
g <- inla.read.graph(filename = "map.adj")
dmerge3 <- dmerge2[order(dmerge2$Year),]
dmerge3$idarea <- as.numeric(as.factor(dmerge3$State))
dmerge3$idarea1 <- dmerge3$idarea
dmerge3$idarea2 <- dmerge3$idarea
dmerge3$idtime <- 1 + dmerge3$Year - min(dmerge3$Year)
dmerge3$idtime1 <-dmerge3$idtime
dmerge3$idtime2 <- dmerge3$idtime
dmerge3$idareatime <- 1:nrow(dmerge3)

#type I model
f1 <- Y ~ f(idarea, model = "bym", graph = g) + GDP + Consumption + Jobs+
  f(idtime, model = "rw2") +
  f(idtime1, model = "iid") +
  f(idareatime, model = "iid")
m1 <- inla(f1, family = "poisson", data = dmerge3, E = E, 
           control.predictor = list(compute = TRUE),
           control.compute=list(dic = TRUE, waic = TRUE, return.marginals.predictor=TRUE))
summary(m1) #DIC = 10600.14

#posterior plot
us.fit <-data.frame(cbind(fit=m1$summary.fitted.values[,1], "25 perc" = m1$summary.fitted.values[,3], '97.5 perc' = m1$summary.fitted.values[,5], Year=dmerge3$Year))
us.agg <- aggregate(.~Year, data=us.fit, median)
plot(us.agg$Year, us.agg$fit, type="l", ylab="SUR", xlab="Year", col="red")
lines(us.agg$Year, us.agg$X97.5.perc, type="l", lty=2, col="red")
lines(us.agg$Year, us.agg$X25.perc, type="l", lty=2, col="red")

#take data from 2022
d2022 <- dmerge[which(dmerge$Year=='2022'),]
rownames(d2022) <- d2022$ID
d2022$SUR <-m1$summary.fitted.values[c(613, 615:623, 625:663),1]

#merge spatial, outcome, and covariates together
library(sp)
map2022 <- SpatialPolygonsDataFrame(map, d2022, match.ID = TRUE)

#plot SUR in 2022
library(leaflet)
l <- leaflet(map2022) %>% addTiles()
pal <- colorNumeric(palette = "YlOrRd", domain = map2022$SUR)
l %>%
  addPolygons(
    color = "grey", weight = 1,
    fillColor = ~ pal(SUR), fillOpacity = 0.5
  ) %>%
  addLegend(
    pal = pal, values = ~SUR, opacity = 0.5,
    title = "SUR", position = "bottomright"
  )

#check space-time interaction
n.time <- length(unique(dmerge3$Year))
delta.1 <- matrix(m1$summary.random$idareatime$mean, byrow=F, ncol=n.time)
par(mfrow=c(2,3))
plot(1:n.time, delta.1[45,], type="b", ylab="delta", xlab="year", main="California")
plot(1:n.time, delta.1[2,], type="b", ylab="delta", xlab="year", main="Florida")
plot(1:n.time, delta.1[15,], type="b", ylab="delta", xlab="year", main="Massachusetts")
plot(1:n.time, delta.1[27,], type="b", ylab="delta", xlab="year", main="New York")
plot(1:n.time, delta.1[39,], type="b", ylab="delta", xlab="year", main="Texas")
plot(1:n.time, delta.1[16,], type="b", ylab="delta", xlab="year", main="Michigan")

#type III model
f2 <- Y ~ f(idarea, model = "bym", graph = g) + GDP + Consumption + Jobs+
  f(idtime, model = "rw2") +
  f(idtime1, model = "iid") +
  f(idtime2, model = "iid",group = idarea2, control.group = list(model = "besag", graph = g))
m2 <- inla(f2, family = "poisson", data = dmerge3, E = E, control.predictor = list(compute = TRUE)
           ,control.compute=list(dic = TRUE))
summary(m2) #DIC = 10600.17

#type II model 
f3 <- Y ~ f(idarea, model = "bym", graph = g) + GDP + Consumption + Jobs+
  f(idtime, model = "rw2") +
  f(idtime1, model = "iid") +
  f(idarea2, model = "iid", group = idtime2, control.group = list(model = "rw2"))
m3 <- inla(f3, family = "poisson", data = dmerge3, E = E, control.predictor = list(compute = TRUE), control.compute=list(dic = TRUE))
summary(m3) #DIC = 10603.30

#type IV model 
f4 <- Y ~ f(idarea, model = "bym", graph = g) + GDP + Consumption + Jobs+
  f(idtime, model = "rw2") +
  f(idtime1, model = "iid") +
  f(idarea2,model = "besag", graph = g, group = idtime, 
    control.group = list(model = "rw2"))
m4 <- inla(f4, family = "poisson", data = dmerge3, E = E, control.predictor = list(compute = TRUE), control.compute=list(dic = TRUE))
summary(m4) #DIC = 10603.30



