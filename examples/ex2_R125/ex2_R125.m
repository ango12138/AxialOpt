%% AxialOpt - A MATLAB program to optimize axial turbines
% Author: Roberto Agromayor
% Date: Spring 2021


%% Initialize the program
% Clear all variables and close all figures
clear all
close all
clc

% Add the path to the 'source_code' directory
% The function genpath() is very convenient
addpath(genpath('../../source_code'))

% Set a project name (mfilename corresponds to the script name)
project_name = mfilename;

% Create a directory to store the figures and results
results_path = fullfile(pwd, [project_name, '_results']);
if exist(results_path, 'dir') ~= 7    % 7 is a MATLAB's convention
    mkdir(results_path)
else
    rmdir(results_path, 's')
    mkdir(results_path)
end


%% Define mean-line model fixed parameters
% Define the loss model used to compute the entropy generation
% Valid options:
%  1. Set 'AM' to use the Ainley-Mathieson loss model (1951)
%  2. Set 'DC' to use the Dunham-Came loss model (1970)
%  3. Set 'KO' to use the Kacker-Okapuu loss model (1982)
loss_system = 'KO';

% Choose the definition of the loss coefficient
% Valid options:
%  1. Set 'p0' to use the stagnation pressure loss coefficient
%  2. Set 'h' to use the enthalpy-based loss coefficient
%  3. Set 's' to use the entropy-based loss coefficient
loss_coefficient = 'p0';

% Define the objective function
% Set 'total-to-static' or 'total-to-total'
obj_function = 'total-to-static';

% Define the number of stages
n_stages = 1;

% Define the working fluid
fluid = 'HEOS::R125';

% Define the thermodynamic specifications of the design problem
% These are usually obtained from a system-level analysis
% Specify inlet enthalpy if the expansion starts from the two-phase region
T0_in = 155.00+273.15;                                                     % Inlet stagnation temperature in (K) (provide the stagnation enthalpy instead if the expansion starts in the two-phase region)
p0_in = 36.18e5;                                                           % Inlet stagnation pressure in (Pa)
h0_in = prop_calculation('H','T',T0_in,'P',p0_in,fluid);
p_out = 15.69e5;                                                           % Outlet static pressure in (Pa)

% Define the mass flow rate (kg/s)
% mass_flow = [];

% Compute the mass flow rate using the isentropic power output
isentropic_power = 250e3;                                                  % Isentropic power in (W)
s_in = prop_calculation('S','T',T0_in,'P',p0_in,fluid);                    % Inlet entropy in (J/kg K)
h_out_s = prop_calculation('H','P',p_out,'S',s_in,fluid);                  % Outlet static isentropic enthalpy (J/kg)
mass_flow = isentropic_power/(h0_in-h_out_s);                              % Mass flow rate (kg/s)

% Define the tip clearance gap (m)
t_cl = 5e-4;                                                               % Values between 0.2-0.5 mm are reasonable

% Define the first stator inlet flow angle (rad)
angle_in = 0.00*pi/180;                                                    % Using and axial entry stator row is reasonable (algle_in = 0.00)

% Choose the type of diffuser model. Valid options:
%  1. diffuser_model='1D' (does not work in the two-phase region)
%  2. diffuser_model='isentropic' (simpler and faster alternative)
%  3. diffuser_model='no' (skips the diffuser computation)
diffuser_model = '1D';

% Define the diffuser design parameters (ignored if diffuser_model='no')
phi = 30*pi/180;                                                           % Diffuser mean cant angle (rad)
div = 5*pi/180;                                                            % Diffuser divergence semiangle (rad)
AR = 2.000;                                                                % Diffuser area ratio (set a value close to one for the no-diffuser case)
Cf = 0.010;                                                                % Skin friction coefficient (only for 1D model). Dubitsky–Japikse (2008) suggest 0.010 as a reasonable estimate


%% Define the independent variables and bounds
% Specific speed
w_s = 1.00;                                                                % Easier to guess than the angular speed
w_s_min = 0.01;                                                            % The range 0.01-10.0 covers almost all cases
w_s_max = 10.0;                                                            % This range can be extended if desired

% Specific diameter
d_s = 2/sqrt(n_stages)/w_s;                                                % Easier to guess than the actual diameter. Setting 2/sqrt(n_stages)/w_s gives good results
d_s_min = 0.01;                                                            % The range 0.1-10.0 covers almost all cases
d_s_max = 10.0;                                                            % This range can be extended if desired

% Reduced velocity at the inlet of the first stator
vel_in = 0.20;
vel_in_min = 0.001;                                                        % The reduced velocity is positive
vel_in_max = 0.500;                                                        % The reduced velocity is lower than 1.00

% Reduced relative velocity at the outlet of each cascade
vel_out(1:2:2*n_stages-1) = 1/sqrt(2*n_stages);                            % Reduced relative velocity at the outlet of the stators. 1/sqrt(2*n_stages); is a good initial guess
vel_out(2:2:2*n_stages)   = 1/sqrt(2*n_stages);                            % Reduced relative velocity at the outlet of the rotors. 1/sqrt(2*n_stages); is a good initial guess
vel_out_min(1:2*n_stages) = 0.05;                                          % The reduced velocity is positive
vel_out_max(1:2*n_stages) = 1.25;                                          % The reduced velocity is lower than 1.00

% Relative angle at the outlet of each cascade
ang_out(1:2:2*n_stages-1) = +70/180*pi;                                    % Relative angle at the outlet of each stator
ang_out(2:2:2*n_stages)   = -70/180*pi;                                    % Relative angle at the outlet of each rotor
ang_out_min(1:2:2*n_stages-1) = +40/180*pi;                                % The low limit of the Ainley-Mathieson profile loss correlation for the relative angle at the outlet of the stator is +40 deg (tricky sign convention)
ang_out_min(2:2:2*n_stages)   = -80/180*pi;                                % The low limit of the Ainley-Mathieson profile loss correlation for the relative angle at the outlet of the rotor is -80 deg (tricky sign convention)
ang_out_max(1:2:2*n_stages-1) = +80/180*pi;                                % The high limit of the Ainley-Mathieson profile loss correlation for the relative angle at the outlet of the stator is +80 deg (tricky sign convention)
ang_out_max(2:2:2*n_stages)   = -40/180*pi;                                % The high limit of the Ainley-Mathieson profile loss correlation for the relative angle at the outlet of the rotor is -40 deg (tricky sign convention)

% Aspect ratio
r_Hc(1:2*n_stages) = 1.25;                                                 % Blade height to actual chord aspect ratio (not axial chord)
r_Hc_min(1:2*n_stages) = 1.00;                                             % Saravanamuttoo advises against aspect ratios lower than 1.00
r_Hc_max(1:2*n_stages) = 2.00;                                             % Saravanamuttoo indicates that high values may leed to vibration problems. Values around 3.00-4.00 are safe

% Pitch to chord ratio
r_sc(1:2*n_stages) = 0.75;                                                 % Spacing to chord ratio (inverse of solidity in US terminology)
r_sc_min(1:2*n_stages) = 0.30;                                             % The low limit of the Ainley-Mathieson profile loss correlation for the pitch to chord ratio is 0.30                              
r_sc_max(1:2*n_stages) = 1.10;                                             % The high limit of the Ainley-Mathieson profile loss correlation for the pitch to chord ratio is 1.10                             

% Entropy at the outlet of each cascade
% Initial guess: compute the exit entropy for a reference isentropic
% efficiency and then assume a linear distribution from inlet to exit
eta = 0.80;
s_in  = prop_calculation('S','H',h0_in,'P',p0_in,fluid);
h_out_s = prop_calculation('H','P',p_out,'S',s_in,fluid);
h_out = h0_in-eta*(h0_in-h_out_s);
s_ref = prop_calculation('S','P',p_out,'H',h_out,fluid);
s_out = linspace(1, s_ref/s_in, 2*n_stages+1);
s_out = s_out(2:end);
s_out_min(1:2*n_stages) = 1.00;
s_out_max(1:2*n_stages) = 2.00;


%% Define the constraints
% Instructions:
% 1. Specify the minimum and maximum values
% 2. Specify whether to apply the constraint or not
% 3. Specify a reference value to scale the problem 
% 4. Use [brackets] to ignore the constraint value

% Flaring angle
constraints.flare_angle.min = -10*pi/180;                                  % Ainley and Mathieson (March 1951) recommend a maximum of 12.5 deg
constraints.flare_angle.max = +10*pi/180;                                  % Ainley and Mathieson (March 1951) recommend a maximum of 12.5 deg
constraints.flare_angle.applied = 'yes';
constraints.flare_angle.ref = 1.00;

% Hub-to-tip ratio
constraints.r_ht.min = 0.600;                                              % Kacker-Okapuu correlation holds for values as low as 0.500. Saravanamuttoo discusses ratios as low as 0.50.
constraints.r_ht.max = 0.900;                                              % High values imply large secondary losses (the accuracy of all secondary loss models is questionable) 
constraints.r_ht.applied = 'yes';
constraints.r_ht.ref = 1.00;

% Degree of reaction 
constraints.reaction.min = 0.100;                                          % Avoid pressure increase in rotor cascades  (R>0)
constraints.reaction.max = 0.900;                                          % Avoid pressure increase in stator cascades (R<1)
constraints.reaction.applied = 'yes';
constraints.reaction.ref = 1.00;

% Relative Mach number
constraints.Ma_rel.min = [];
constraints.Ma_rel.max = 5.000;                                            % Set an arbitrary limit for the maximum relative Mach number if desired
constraints.Ma_rel.applied = 'yes';
constraints.Ma_rel.ref = 1.00;

% Diffuser inlet Mach number
constraints.Ma_diffuser.min = [];
constraints.Ma_diffuser.max = 0.95;                                        % Constraint the diffuser to be subsonic (prevent the diffuser to behave as a supersonic nozzle)
constraints.Ma_diffuser.applied = 'yes';
constraints.Ma_diffuser.ref = 1.00;

% Constrain inlet angles (avoid too low deflection)
constraints.beta_in_stator.min = [];
constraints.beta_in_stator.max = +15/180*pi;                               % Kacker and Okapuu (1982) propose a correlation with a maximum value of +30 deg for stator cascades
constraints.beta_in_stator.applied = 'yes';
constraints.beta_in_stator.ref = 1.00;

% Constrain inlet angles (avoid too low deflection)
constraints.beta_in_rotor.min = -15/180*pi;                                % Kacker and Okapuu (1982) propose a correlation with a minimum value of -30 deg for rotor cascades 
constraints.beta_in_rotor.max = [];
constraints.beta_in_rotor.applied = 'yes';
constraints.beta_in_rotor.ref = 1.00;

% Minimum height constraint
constraints.height.min = 0.01;                                             % Insert any value in [m]
constraints.height.max = [];
constraints.height.applied = 'no';
constraints.height.ref = 0.01;
                                                                    
% Minimum chord constraint
constraints.chord.min = 0.01;                                              % Insert any value in [m]
constraints.chord.max = [];
constraints.chord.applied = 'no';
constraints.chord.ref = 0.01;

% Angular speed constraint
constraints.RPM.min = 3600;                                                % Insert any value in [rpm]
constraints.RPM.max = 3600;                                                % 3000 or 3600 for syncronous speed in Europe or USA, respectively
constraints.RPM.applied = 'no';
constraints.RPM.ref = 10000;

% In order to add new constraints you have to:
%    1. Add the desired constraint in this section of the code
%    2. Modify the function evaluate_constraints() in the source code


%% Define optimization algorithm settings
% Set optimization algorithm
% 'spq' is my favourite because it converges reliably and respects bounds
% 'active-set' is a bit more aggressive and does not always respect the
% bounds. It is faster, but less reliable, than 'sqp'.
% 'interior-point' also works, but it requires more iterations
algorithm = 'sqp';

% Compute the problem gradients in parallel or not
use_parallel = false; % true or false

% Define termination criteria (no need to change in most cases)
% Ignoring the optimality_tolerance is recommended in most cases
max_iterations       = 1000;
max_function_evals   = 10000;
step_tolerance       = 1e-08;
function_tolerance   = 1e-05;
constraint_tolerance = 1e-05;
optimality_tolerance = 1e-00;   

% Description of the possible outputs of the optimization function
%{

'interior-point', 'active-set', and 'sqp' algorithms
Exitflag =  1 -> Success. First-order optimality measure was less than options and constraints are not violated.
Exitflag =  2 -> Success. Step size was less than options and constraints are not violated.
Exitflag =  0 -> Unsuccess. Number of iterations or function evaluations exceeded option
Exitflag = -1 -> Unsuccess. Solver stopped by an output function
Exitflag = -2 -> Unsuccess. No feasible point was found

Only active set algorithm
Exitflag =  4 -> Success. Magnitude of the search direction was less than 2*options.StepTolerance and maximum constraint violation was less than options.ConstraintTolerance.
Exitflag =  5 -> Success. Magnitude of directional derivative in search direction was less than 2*options.OptimalityTolerance and maximum constraint violation was less than options.ConstraintTolerance.

%}

                 
%% Choose what figures should be plotted
choose_plots = struct('diagram_hs',            'no', ...                  % Enthalpy-entropy diagram of the expansion
                      'diagram_Ts',            'yes', ...                  % Temperature-entropy diagram of the expansion
                      'plot_satline',          'yes', ...                  % Plot the saturation line in the h-s or T-s diagrams
                      'axial_tangential',      'yes', ...                  % View of the blade cascades
                      'axial_radial',          'yes', ...                  % View of the meridional plane
                      'triangles_A',           'no', ...                  % Velocity triangles with blade velocity common origin
                      'triangles_B',           'no', ...                  % Velocity triangles with flow velocity common origin
                      'loss_breakdown',        'yes', ...                  % Breakdown of the efficiency loss
                      'save',                  0);                         % Choose whether to save the figures or not

% Description of the saving options
%{

save=0 does not save the figures
save=1 saves the figure in vector format using the default MATLAB export function (faster)
save=2 saves the figure in vector using the export_fig library (requires ghostscript)     
                                                              
In order to use save=2 it is necessary to install 'ghostscript'
  https://github.com/altmany/export_fig
  http://www.ghostscript.com
  http://xpdfreader.com

%}

% TODO update saving options


%% Store the parameters defined up to this point into data structures
% The script 'create_problem_structures' located in source_code folder
%  1) 'fixed_parameters' stores the design specifications 
%  2) 'optimization_problem' stores the optimization problem settings
create_problem_structures

% These data structures are created in a different script to avoid
% the repetition of the code in every project

% Be tidy and clear the worskpace now that we stored everything
clearvars -except optimization_problem fixed_parameters project_name results_path


%% Use a previous solution as initial guess
% % Uncomment these lines to use a previous solution as initial guess
% load('turbine_data.mat')
% optimization_problem.x0 = turbine_data.optimization.x;


%% Plot the initial guess
filename_suffix = 'initial';
turbine_data = create_plots(optimization_problem.x0,fixed_parameters,filename_suffix);
print_solution(turbine_data)


%% Solve the optimization problem and save the solution
[turbine_data,x_opt,f_opt,exitflag,output] = solve_optimization_problem(fixed_parameters,optimization_problem);
save_solution(turbine_data, project_name, results_path)


%% Plot the optimal solution
filename_suffix = 'optimal';
turbine_data = create_plots(x_opt,fixed_parameters,filename_suffix);
print_solution(turbine_data)


