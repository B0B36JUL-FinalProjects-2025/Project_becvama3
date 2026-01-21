using Test
using StaticArrays
using LinearAlgebra
using OrbiJul.Simulator 

@testset "Physics Logic" begin

    @testset "Inverse Square Law" begin
        # Setup: Two bodies, distance 10
        b1 = PhysicsBody(@SVector[0f0,0,0], @SVector[0f0,0,0], 100f0)
        b2 = PhysicsBody(@SVector[10f0,0,0], @SVector[0f0,0,0], 10f0)
        
        # Calculate Force manually: F = G * m1 * m2 / r^2
        # F = 10 * 100 * 10 / 100 = 100
        # Acceleration on b2 = F / m2 = 100 / 10 = 10
        
        # We need to expose a way to get acceleration or step once
        # Let's verify via a single Euler step
        step!([b1, b2], 1.0f0, nothing, UInt64(1), EulerSolver())
        
        # b2 was at 10.0, vel 0. 
        # After 1 sec, vel should be -10.0 (pulled left)
        # Position change depends on implementation (vel * dt), roughly 0 or -10
        
        @test b2.vel[1] ≈ -10.0f0 atol=0.1
    end

    @testset "Conservation of Energy (Verlet)" begin
        # Verlet should conserve Total Energy (Kinetic + Potential)
        # Euler should NOT. This proves the solvers are different.
        
        function total_energy(bodies)
            # Kinetic = 0.5 * m * v^2
            ke = sum(0.5f0 * b.mass * sum(abs2, b.vel) for b in bodies)
            
            # Potential = -G * m1 * m2 / r
            pe = 0f0
            for i in 1:length(bodies), j in (i+1):length(bodies)
                r = norm(bodies[i].pos - bodies[j].pos)
                pe -= (10f0 * bodies[i].mass * bodies[j].mass) / r
            end
            return ke + pe
        end

        bodies = [
            PhysicsBody(@SVector[0f0,0,0], @SVector[0f0,0,0], 1000f0),
            PhysicsBody(@SVector[50f0,0,0], @SVector[0f0,10f0,0], 10f0)
        ]
        
        start_energy = total_energy(bodies)
        
        for _ in 1:1000
            step!(bodies, 0.016f0, nothing, UInt64(1), VelocityVerletSolver())
        end
        
        end_energy = total_energy(bodies)
        
        # Energy should be conserved within floating point error
        @test isapprox(start_energy, end_energy, rtol=0.01)
    end

    @testset "Solver Comparison: High Stress (Elliptical)" begin
        function get_energy(bodies)
            ke = sum(0.5f0 * b.mass * sum(abs2, b.vel) for b in bodies)
            pe = 0f0
            n = length(bodies)
            for i in 1:n, j in (i+1):n
                dist = norm(bodies[i].pos - bodies[j].pos)
                pe -= (10f0 * bodies[i].mass * bodies[j].mass) / dist
            end
            return ke + pe
        end

        # ellipse 
        r_start = @SVector[10f0, 0f0, 0f0]
        v_start = @SVector[0f0, 12f0, 0f0] 
        
        bodies_euler = [
            PhysicsBody(@SVector[0f0,0,0], @SVector[0f0,0,0], 100f0),
            PhysicsBody(r_start, v_start, 1f0)
        ]
        bodies_verlet = deepcopy(bodies_euler)
        bodies_rk4 = deepcopy(bodies_euler)

        #  Long Simulation 
        dt = 0.016f0
        steps = 10000 

        start_energy = get_energy(bodies_euler)

        # Run Euler
        for _ in 1:steps
            step!(bodies_euler, dt, nothing, UInt64(1), EulerSolver())
        end
        
        # Run Verlet
        for _ in 1:steps
            step!(bodies_verlet, dt, nothing, UInt64(1), VelocityVerletSolver())
        end

        # Run RK4
        for _ in 1:steps
            step!(bodies_rk4, dt, nothing, UInt64(1), RK4Solver())
        end

        # Results 
        err_euler = abs(start_energy - get_energy(bodies_euler))
        err_verlet = abs(start_energy - get_energy(bodies_verlet))
        err_rk4 = abs(start_energy - get_energy(bodies_rk4))
        
        # Calculate ratio
        ratio = err_euler / err_verlet

        println("\n=== Verlet vs Euler vs RK4 TEST RESULTS ===")
        println("Euler Drift:  $err_euler")
        println("Verlet Drift: $err_verlet")
        println("RK4 Drift: $err_rk4")
        println("Euler is $(round(ratio, digits=1))x worse than Verlet")
        println("================================\n")

        @test err_euler > (err_verlet * 10.0) # Euler must be at least 10x worse
    end
    
    @testset "Type Stability" begin
        bodies = [PhysicsBody(@SVector[0f0,0,0], @SVector[0f0,0,0], 1f0)]
        @test (@inferred Simulator.calculate_accelerations(bodies) isa Vector)
    end
end
