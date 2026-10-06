# Stage 1: Base Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Development

# Stage 2: SDK Build & Restore
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file first to leverage Docker layer caching for dependencies
COPY ["src/StyleSync.Api/StyleSync.Api.csproj", "src/StyleSync.Api/"]
RUN dotnet restore "src/StyleSync.Api/StyleSync.Api.csproj"

# Copy source files and build
COPY ["src/StyleSync.Api/", "src/StyleSync.Api/"]
WORKDIR "/src/src/StyleSync.Api"
RUN dotnet build "StyleSync.Api.csproj" -c Release -o /app/build

# Stage 3: Publish application
FROM build AS publish
RUN dotnet publish "StyleSync.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 4: Final Runtime Image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "StyleSync.Api.dll"]
