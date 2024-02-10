
SELECT * FROM CovidProject.dbo.CovidDeaths
WHERE continent is not NULL
ORDER BY 3,4;

SELECT * FROM CovidProject.dbo.CovidVaccinations
ORDER BY 3,4;

SELECT * FROM CovidProject.dbo.CovidVaccinations;

-- Select Data that we are going to be using

Select Location, date, total_cases, new_cases, total_deaths, population
FROM CovidProject..CovidDeaths
Order By 1,2

-- Looking at Total Cases vs Total Deaths
-- likelihood of death if contract covid in South Korea
Select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
FROM CovidProject..CovidDeaths
WHERE Location like '%Korea%'
Order By 1,2

-- looking at total cases vs. population
-- shows what percentage of population in South Korea got Covid
Select Location, date, population, total_cases,  (total_cases/population)*100 as CovidPopRates
FROM CovidProject..CovidDeaths
WHERE Location like '%states%'
Order By 1,2

-- what countries have the highest infection rates compared to population
Select Location, population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 as PercentPopInfected
FROM CovidProject..CovidDeaths
GROUP BY Location, Population
Order By PercentPopInfected desc

-- breaking things down by continent
SELECT location, MAX(cast(total_deaths as int)) as TotalDeathCount 
FROM CovidProject..CovidDeaths
WHERE continent is NULL
GROUP BY location
Order By TotalDeathCount desc

-- showing countries with highest death count 

SELECT Location, MAX(cast(total_deaths as int)) as TotalDeathCount 
FROM CovidProject..CovidDeaths
WHERE continent is not NULL
GROUP BY Location
Order By TotalDeathCount desc

-- showing continents with highest death count

SELECT continent, MAX(cast(total_deaths as int)) as TotalDeathCount 
FROM CovidProject..CovidDeaths
WHERE continent is not NULL
GROUP BY continent
Order By TotalDeathCount desc

-- global numbers

SELECT SUM(new_cases) as TotalCases, SUM(cast(new_deaths as int)) as TotalDeaths, SUM(cast(new_deaths as int))/SUM(new_cases) * 100 as DeathPercentage
FROM CovidProject..CovidDeaths
WHERE continent is not null
--GROUP BY date
ORDER BY 1,2


-- looking at total population vs vaccinations

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(cast(vac.new_vaccinations as int)) OVER (Partition BY dea.location ORDER BY dea.date) as RollingPeopleVac 
FROM CovidProject..CovidDeaths dea
JOIN CovidProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not NULL
ORDER BY 2, 3

-- USE CTE

WITH PopvsVac (Continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
as 
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(cast(vac.new_vaccinations as int)) OVER (Partition BY dea.location ORDER BY dea.date) as RollingPeopleVac 
FROM CovidProject..CovidDeaths dea
JOIN CovidProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not NULL
-- ORDER BY 2, 3
)
SELECT *, (RollingPeopleVaccinated/Population) * 100
FROM PopvsVac

-- TEMP TABLE
DROP TABLE if exists PercentPopVaccinated
CREATE TABLE PercentPopVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
population numeric, 
new_vaccinations numeric,
RollingPeopleVaccinated numeric
)

INSERT INTO PercentPopVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(cast(vac.new_vaccinations as int)) OVER (Partition BY dea.location ORDER BY dea.date) as RollingPeopleVac 
FROM CovidProject..CovidDeaths dea
JOIN CovidProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not NULL
ORDER BY 2, 3
SELECT *, (RollingPeopleVaccinated/Population) * 100
FROM PercentPopVaccinated


-- Create View to store data for later visualizations

CREATE VIEW PercentPopulationVaccinated as
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(cast(vac.new_vaccinations as int)) OVER (Partition BY dea.location ORDER BY dea.date) as RollingPeopleVac 
FROM CovidProject..CovidDeaths dea
JOIN CovidProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not NULL
--ORDER BY 2, 3
