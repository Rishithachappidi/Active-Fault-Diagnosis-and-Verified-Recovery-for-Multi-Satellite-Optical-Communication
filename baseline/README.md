# Dynamic Event-Triggered and Self-Triggered Fault-Tolerant Attitude Control for Multiple Spacecraft

## Overview

This project implements a **four-spacecraft attitude control system** using MATLAB and Simulink.

The aim is to coordinate the attitude and angular velocity of four spacecraft while considering actuator faults, input saturation, disturbances, and limited communication between spacecraft.

The project includes three control strategies:

- Time-Driven Control
- Dynamic Event-Triggered Control
- Self-Triggered Control

Along with the MATLAB/Simulink implementation, an interactive web visualization is included to show how the four spacecraft behave during the simulation.

---

## What We Implemented

The system contains four spacecraft with different:

- Initial attitudes
- Initial angular velocities
- Inertia matrices
- Actuator effectiveness values

The spacecraft exchange information through a directed communication network.

During the simulation, each spacecraft calculates its coordination error using its own state, its neighboring spacecraft states, and the desired reference state.

The main coordination variable is

\[
s_i = e_{2i} + r e_{1i}
\]

where:

- \(e_{1i}\) represents the attitude coordination error
- \(e_{2i}\) represents the angular velocity coordination error

The controller uses this error to generate the required control torque.

The spacecraft dynamics also include:

- Actuator effectiveness loss
- Input saturation
- External disturbances
- Drift torque

The maximum actuator torque used in the simulation is:

\[
u_{max}=0.2\;N\cdot m
\]

---

## Control Cases

### Case 1 — Time-Driven Control

The controller updates at a fixed frequency of **10 Hz**.

This means the control input is recalculated every **0.1 seconds**.

---

### Case 2 — Dynamic Event-Triggered Control

The controller is updated only when the event-trigger condition is satisfied.

Instead of communicating continuously, each spacecraft sends new state information only when an update is required.

This helps reduce unnecessary communication between the spacecraft.

The event-trigger condition is based on the difference between the stored coordination state and the current coordination state.

---

### Case 3 — Self-Triggered Control

The self-triggered controller calculates the next controller update time in advance.

Instead of continuously checking the event condition, the spacecraft determines when the next update should occur and waits until that time.

This reduces continuous trigger-condition checking.

---

## Simulation Flow

The overall system works as follows:

```text
Initial spacecraft states
        ↓
Desired attitude and angular velocity
        ↓
Neighbor spacecraft information
        ↓
Calculate attitude error
        ↓
Calculate angular velocity error
        ↓
Calculate coordination variable s
        ↓
Controller / Trigger mechanism
        ↓
Calculate control input
        ↓
Apply actuator saturation
        ↓
Apply actuator effectiveness
        ↓
Add disturbances and drift torque
        ↓
Spacecraft dynamics
        ↓
Updated attitude and angular velocity
        ↓
Repeat
```

As the simulation progresses, the attitude error, angular velocity error, and coordination error decrease and the four spacecraft move toward coordinated attitude behavior.

---

## MATLAB / Simulink Files

The main implementation is available inside the `simulation/` folder.

### `sff_params.m`

Contains the simulation parameters, communication matrices, controller parameters, inertia matrices, actuator effectiveness matrices, initial conditions, and simulation settings.

### `sff_x0.m`

Creates the initial state vector for all four spacecraft.

### `sff_ref.m`

Generates the desired attitude and desired angular velocity.

### `sff_plant_core.m`

Implements the spacecraft attitude and angular velocity dynamics, including actuator faults, disturbances, drift torque, and control input.

### `sff_controller_core.m`

Implements all three controller cases:

- Time-Driven Control
- Dynamic Event-Triggered Control
- Self-Triggered Control

It also handles controller updates, stored states, triggering logic, and communication between spacecraft.

### `sff_build_model.m`

Creates and configures the Simulink model.

### `sff_ets_model.slx`

Main Simulink model used for the project.

### `sff_run_all.m`

Runs all three control cases and generates the simulation output plots.

---

## Interactive Visualization

The project also includes an interactive visualization through:

```text
index.html
```

The visualization shows:

- Four spacecraft
- Different initial orientations
- Different angular velocities
- Communication links
- Desired reference state
- Attitude error
- Angular velocity error
- Coordination variable \(s_i\)
- Trigger events
- Controller updates
- Control input
- Saturated control input
- Live error plots
- Trigger timeline

The user can switch between all three controller cases and observe how the system behavior changes.

---



## Project Outcome

The project demonstrates how four spacecraft with different initial attitudes and angular velocities can achieve coordinated attitude behavior using distributed control.

The main comparison is between:

- Fixed periodic controller updates
- Event-based controller updates
- Predicted self-triggered controller updates

The visualization helps show how spacecraft errors decrease, how communication takes place between spacecraft, and how different triggering strategies affect controller updates.

---

## Reference

X. Xie, T. Sheng, and X. Chen,  
**“Dynamic Event-Triggered and Self-Triggered Fault-Tolerant Attitude Control for Multiple Spacecraft Systems With Uncertainties and Input Saturation,”**  
IEEE Transactions on Aerospace and Electronic Systems, 2024.

DOI: `10.1109/TAES.2024.3355381`

##Author 
Rishitha C 
