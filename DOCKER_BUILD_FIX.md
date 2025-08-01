# Docker Build Fix - Test Project Dependencies

## Problem
The Docker build for `Dockerfile.combined` was failing with errors:
```
The project file "/src/tests/AjudadoraBot.UnitTests/AjudadoraBot.UnitTests.csproj" was not found
The project file "/src/tests/AjudadoraBot.IntegrationTests/AjudadoraBot.IntegrationTests.csproj" was not found
The project file "/src/tests/AjudadoraBot.E2ETests/AjudadoraBot.E2ETests.csproj" was not found
The project file "/src/tests/AjudadoraBot.PerformanceTests/AjudadoraBot.PerformanceTests.csproj" was not found
```

## Root Cause
The issue occurred because:
1. The `AjudadoraBot.sln` file contains references to all test projects
2. The Dockerfile copied the solution file but only copied the `src/` directory (not `tests/`)
3. When `dotnet restore` ran against the solution file, it tried to restore all projects including the missing test projects

## Solution Applied
Modified `Dockerfile.combined` to exclude test projects from the build process:

### Changes Made:

1. **Removed solution file copying**:
   ```dockerfile
   # BEFORE (line 58)
   COPY *.sln ./
   
   # AFTER (removed)
   # Solution file no longer copied
   ```

2. **Updated dotnet restore to target specific project**:
   ```dockerfile
   # BEFORE (line 64)
   RUN dotnet restore --runtime linux-musl-x64 --no-cache --verbosity minimal
   
   # AFTER (line 63)
   RUN dotnet restore src/AjudadoraBot.Api/AjudadoraBot.Api.csproj --runtime linux-musl-x64 --no-cache --verbosity minimal
   ```

3. **Updated dotnet build to target specific project**:
   ```dockerfile
   # BEFORE (line 70)
   RUN dotnet build -c Release --no-restore --runtime linux-musl-x64 --verbosity minimal && \
   
   # AFTER (line 69)
   RUN dotnet build src/AjudadoraBot.Api/AjudadoraBot.Api.csproj -c Release --no-restore --runtime linux-musl-x64 --verbosity minimal && \
   ```

## Benefits of This Approach

1. **Production Focus**: Test projects are not needed in production containers
2. **Smaller Image Size**: Excludes test dependencies and files
3. **Faster Build**: No unnecessary test project restoration/compilation
4. **Reliability**: Eliminates dependency on test project availability in Docker context
5. **Maintainability**: Clearer separation between production and development builds

## Validation

The fix has been validated to ensure:
- ✅ Solution file (.sln) is no longer copied
- ✅ `dotnet restore` targets the main API project specifically
- ✅ `dotnet build` targets the main API project specifically
- ✅ All production optimizations for Azure App Service F1 tier are maintained
- ✅ Project dependencies (Core → Infrastructure → API) are preserved

## Testing the Fix

To test the Docker build:

```bash
# Build the image
docker build -f Dockerfile.combined -t ajudadorabot-combined:latest .

# Test the container
docker run --rm -d --name ajudadorabot-test -p 8080:8080 ajudadorabot-combined:latest

# Check health endpoint
curl http://localhost:8080/health

# Cleanup
docker stop ajudadorabot-test
```

## Alternative Solutions Considered

1. **Copy test projects**: Would increase image size and build time unnecessarily
2. **Create separate solution file**: Would require maintaining multiple solution files
3. **Use .dockerignore**: Would still require copying the solution file with test references

The chosen solution (targeting specific projects) is the most efficient for production deployments.

## Files Modified

- `C:\DEV\pessoal\AjudadoraBot\Dockerfile.combined` - Main fix applied
- `C:\DEV\pessoal\AjudadoraBot\scripts\test-docker-build.ps1` - Testing script created
- `C:\DEV\pessoal\AjudadoraBot\scripts\validate-docker-fix.ps1` - Validation script created

## Status
✅ **READY FOR TESTING** - The Docker build should now complete successfully without test project dependency errors.