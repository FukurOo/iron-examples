!> \file
!> \author Adam Reeve
!> \brief This is an example program to solve a finite elasticity equation using OpenCMISS calls.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s): Adam Reeve, Thomas Heidlauf
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!> \example FiniteElasticity/LargeUniAxialExtension/src/LargeUniAxialExtensionExample.f90
!! Example program to solve a finite elasticity equation using openCMISS calls.
!! \par Latest Builds:
!! \li <a href='http://autotest.bioeng.auckland.ac.nz/opencmiss-build/logs_x86_64-linux/FiniteElasticity/LargeUniAxialExtension/build-intel'>Linux Intel Build</a>
!! \li <a href='http://autotest.bioeng.auckland.ac.nz/opencmiss-build/logs_x86_64-linux/FiniteElasticity/LargeUniAxialExtension/build-gnu'>Linux GNU Build</a>
!<

!> Main program
PROGRAM LARGEUNIAXIALEXTENSIONEXAMPLE

  USE OpenCMISS
  USE OpenCMISS_Iron
#ifndef NOMPIMOD
  USE MPI
#endif

#ifdef WIN32
  USE IFQWIN
#endif

  IMPLICIT NONE

#ifdef NOMPIMOD
#include "mpif.h"
#endif

  !--------------------------------------------------------------------------------------------------------------------------------
  !Test program parameters
!  real etime          ! Declare the type of etime()
  real :: elapsed(2)     ! For receiving user and system time
  real :: total 

  REAL(CMISSRP), PARAMETER :: tol=1.0E-8_CMISSRP

!  REAL(CMISSRP), PARAMETER :: Vmax=1.0_CMISSRP !TODO ????? TODO TODO TODO TODO TODO 
  REAL(CMISSRP), PARAMETER :: Vmax=-0.2_CMISSRP!-0.02_CMISSRP
  
  LOGICAL :: independent_field_auto_create=.FALSE.

  INTEGER(CMISSIntg) :: NumberOfElementsFE
  INTEGER(CMISSIntg) :: NumberOfElementsM
  INTEGER(CMISSIntg) :: NumberOfNodesM
  INTEGER(CMISSIntg) :: NumberOfNodesPerFibre,NumberOfFibres
  INTEGER(CMISSIntg), PARAMETER :: NumberOfInSeriesFibres=1

  integer(CMISSIntg) :: stat
  character(len=256) :: filename,filename2,pathname

  INTEGER(CMISSIntg) :: NumberGlobalXElements,NumberGlobalYElements,NumberGlobalZElements
  INTEGER(CMISSIntg) :: mu_nr,Ftype,fibre_nr,NearestGP,InElement
  
  logical :: less_info,fast_twitch

  INTEGER(CMISSIntg) :: val

  INTEGER(CMISSIntg), DIMENSION(10000,100) :: FIRING_TIMES
  INTEGER(CMISSIntg), ALLOCATABLE :: IZ_offset(:)

  INTEGER(CMISSIntg), ALLOCATABLE :: mu_distri(:)

  !--------------------------------------------------------------------------------------------------------------------------------

  !all lengths in [cm]
  REAL(CMISSRP), PARAMETER :: LENGTH=6.0_CMISSRP ! X-direction
  REAL(CMISSRP), PARAMETER :: WIDTH= 3.0_CMISSRP ! Y-direction
  REAL(CMISSRP), PARAMETER :: HEIGHT=1.5_CMISSRP ! Z-direction
  
  !all times in [ms]
  REAL(CMISSRP) :: time !=10.00_CMISSRP 
  REAL(CMISSRP), PARAMETER :: PERIODD=1.00_CMISSRP
  REAL(CMISSRP), PARAMETER :: TIME_STOP=1000.0_CMISSRP

!  REAL(CMISSRP), PARAMETER :: ODE_TIME_STEP=0.00001_CMISSRP
  REAL(CMISSRP), PARAMETER :: ODE_TIME_STEP=0.0001_CMISSRP
  REAL(CMISSRP), PARAMETER :: PDE_TIME_STEP=0.0005_CMISSRP
  REAL(CMISSRP), PARAMETER :: ELASTICITY_TIME_STEP=0.10000000001_CMISSRP!0.5_CMISSRP!0.05_CMISSRP!0.8_CMISSRP
!tomo keep ELASTICITY_TIME_STEP and STIM_STOP at the same values
  REAL(CMISSRP), PARAMETER :: STIM_STOP=0.1_CMISSRP!ELASTICITY_TIME_STEP

  INTEGER(CMISSIntg), PARAMETER :: OUTPUT_FREQUENCY=10
  
  !--------------------------------------------------------------------------------------------------------------------------------
  !stimulation current in [uA/cm^2]
  REAL(CMISSRP) :: STIM_VALUE

  !condctivity in [mS/cm]
!  REAL(CMISSRP), PARAMETER :: CONDUCTIVITY=3.828_CMISSRP
!  REAL(CMISSRP), PARAMETER :: CONDUCTIVITY=1.0_CMISSRP
  REAL(CMISSRP), PARAMETER :: CONDUCTIVITY=0.5_CMISSRP

  !surface area to volume ratio in [cm^-1]
!  REAL(CMISSRP), PARAMETER :: Am=500.0_CMISSRP
  REAL(CMISSRP), PARAMETER :: Am=1.0_CMISSRP

  !membrane capacitance in [uF/cm^2]
  REAL(CMISSRP), PARAMETER :: Cm_fast=1.0_CMISSRP 
!  REAL(CMISSRP), PARAMETER :: Cm_slow=0.58_CMISSRP
  REAL(CMISSRP), PARAMETER :: Cm_slow=1.0_CMISSRP
  
  !Material-Parameters C=[mu_1, mu_2, mu_3, alpha_1, alpha_2, alpha_3, mu_0, XB_stiffness]
  REAL(CMISSRP), PARAMETER, DIMENSION(8) :: C = &
    & [0.0085_CMISSRP*5.0_CMISSRP,0.0_CMISSRP,0.0_CMISSRP, & ! [N/cm^2 = 10^4 J/m^3]
    &  11.0_CMISSRP,1.0_CMISSRP,6.0_CMISSRP, &
    &  1.0_CMISSRP,2.2e-9_CMISSRP]      

  !Inital Conditions
  REAL(CMISSRP), PARAMETER :: INITIAL_STRETCH=1.2_CMISSRP
  REAL(CMISSRP), PARAMETER :: CONTRACTION_VELOCITY=-6.0e-1_CMISSRP ![cm/s]
  INTEGER(CMISSIntg), PARAMETER :: TIMESTEPS=1000 !Number of Timesteps

!  REAL(CMISSRP) :: INIT_PRESSURE


  !--------------------------------------------------------------------------------------------------------------------------------
  INTEGER(CMISSIntg), PARAMETER :: CoordinateSystemUserNumberFE=1
  INTEGER(CMISSIntg), PARAMETER :: CoordinateSystemUserNumberM=2
  INTEGER(CMISSIntg), PARAMETER :: NumberOfSpatialCoordinates=3

  INTEGER(CMISSIntg), PARAMETER :: RegionUserNumberFE=1
  INTEGER(CMISSIntg), PARAMETER :: RegionUserNumberM=2

  INTEGER(CMISSIntg), PARAMETER :: QuadraticBasisUserNumber=1
  INTEGER(CMISSIntg), PARAMETER :: LinearBasisUserNumber=2
  INTEGER(CMISSIntg), PARAMETER :: LinearBasisUserNumberM=3
  INTEGER(CMISSIntg), PARAMETER :: NumberOfXiCoordinates=NumberOfSpatialCoordinates
  INTEGER(CMISSIntg), PARAMETER :: NumberOfGaussPoints=3

  INTEGER(CMISSIntg), PARAMETER :: NumberOfMeshDimensionsFE=3

  INTEGER(CMISSIntg), PARAMETER :: GeneratedMeshUserNumber=1
  INTEGER(CMISSIntg), PARAMETER :: MeshUserNumberFE=1
  INTEGER(CMISSIntg), PARAMETER :: MeshUserNumberM=2
  INTEGER(CMISSIntg), PARAMETER :: NumberOfMeshComponentsFE=2
  INTEGER(CMISSIntg), PARAMETER :: QuadraticMeshComponentNumber=1
  INTEGER(CMISSIntg), PARAMETER :: LinearMeshComponentNumber=2
  INTEGER(CMISSIntg), PARAMETER :: MonodomainMeshComponentNumber=1

  INTEGER(CMISSIntg), PARAMETER :: DecompositionUserNumberFE=1
  INTEGER(CMISSIntg), PARAMETER :: DecompositionUserNumberM=2

  INTEGER(CMISSIntg), PARAMETER :: FieldGeometryUserNumberFE=1
  INTEGER(CMISSIntg), PARAMETER :: FieldGeometryUserNumberM=2
  INTEGER(CMISSIntg), PARAMETER :: FieldGeometryNumberOfVariables=1
  INTEGER(CMISSIntg), PARAMETER :: FieldGeometryNumberOfComponents=NumberOfSpatialCoordinates

  INTEGER(CMISSIntg), PARAMETER :: FieldFibreUserNumber=3
  INTEGER(CMISSIntg), PARAMETER :: FieldFibreNumberOfVariables=1
  INTEGER(CMISSIntg), PARAMETER :: FieldFibreNumberOfComponents=3

  INTEGER(CMISSIntg), PARAMETER :: FieldMaterialUserNumberM=4
  INTEGER(CMISSIntg), PARAMETER :: FieldMaterialNumberOfVariablesM=1
  INTEGER(CMISSIntg), PARAMETER :: FieldMaterialNumberOfComponentsM=3 !Am, Cm, Conductiity   !(scalar, since 1D)

  INTEGER(CMISSIntg), PARAMETER :: FieldMaterialUserNumberFE=5
  INTEGER(CMISSIntg), PARAMETER :: FieldMaterialNumberOfVariablesFE=2

  INTEGER(CMISSIntg), PARAMETER :: FieldDependentUserNumberM=6
  INTEGER(CMISSIntg), PARAMETER :: FieldDependentNumberOfVariablesM=3

  INTEGER(CMISSIntg), PARAMETER :: FieldDependentUserNumberFE=7
  INTEGER(CMISSIntg), PARAMETER :: FieldDependentNumberOfVariablesFE=2
  INTEGER(CMISSIntg), PARAMETER :: FieldDependentNumberOfComponentsFE=NumberOfSpatialCoordinates+1

  INTEGER(CMISSIntg), PARAMETER :: FieldIndependentUserNumberFE=8

  INTEGER(CMISSIntg), PARAMETER :: FieldIndependentUserNumberM=9
  INTEGER(CMISSIntg), PARAMETER :: FieldIndependentNumberOfComponentsM1=1
  INTEGER(CMISSIntg), PARAMETER :: FieldIndependentNumberOfComponentsM2=5

  INTEGER(CMISSIntg), PARAMETER :: EquationsSetFieldUserNumberM=10
  INTEGER(CMISSIntg), PARAMETER :: EquationsSetFieldUserNumberFE=11

  INTEGER(CMISSIntg), PARAMETER :: CellMLUserNumber=1
  INTEGER(CMISSIntg), PARAMETER :: CellMLModelsFieldUserNumber=12
  INTEGER(CMISSIntg), PARAMETER :: CellMLStateFieldUserNumber=13
  INTEGER(CMISSIntg), PARAMETER :: CellMLIntermediateFieldUserNumber=14
  INTEGER(CMISSIntg), PARAMETER :: CellMLParametersFieldUserNumber=15

  INTEGER(CMISSIntg), PARAMETER :: EquationsSetsUserNumberM=1
  INTEGER(CMISSIntg), PARAMETER :: EquationsSetsUserNumberFE=2

  INTEGER(CMISSIntg), PARAMETER :: ProblemUserNumber=1

  INTEGER(CMISSIntg), PARAMETER :: SolverDAEIndex=1
  INTEGER(CMISSIntg), PARAMETER :: SolverParabolicIndex=2
  INTEGER(CMISSIntg), PARAMETER :: SolverFEIndex=1

  INTEGER(CMISSIntg), PARAMETER :: ControlLoopMonodomainNumber=1
  INTEGER(CMISSIntg), PARAMETER :: ControlLoopElasticityNumber=2
  
  !Program types
  
  !Program variables

  INTEGER(CMISSIntg) :: EquationsSetIndexM,EquationsSetIndexFE
  INTEGER(CMISSIntg) :: CellMLIndex
  INTEGER(CMISSIntg) :: MPI_IERROR
  INTEGER(CMISSIntg) :: NumberOfComputationalNodes,NumberOfDomains,ComputationalNodeNumber
  
  INTEGER(CMISSIntg) :: NodeNumber,NodeDomain,node_idx,ComponentNumber,domain_idx,ElementDomain
  INTEGER(CMISSIntg) :: NumberOfNodesInXi1,NumberOfNodesInXi2,NumberOfNodesInXi3
  INTEGER(CMISSIntg) :: i,j,k,m,my_node_idx,elem_idx,node1,node2,elem_idx2,NumberOfElementsPerElasticityElement

  INTEGER(CMISSIntg), ALLOCATABLE :: BottomSurfaceNodes(:)
  INTEGER(CMISSIntg), ALLOCATABLE :: LeftSurfaceNodes(:)
  INTEGER(CMISSIntg), ALLOCATABLE :: RightSurfaceNodes(:)
  INTEGER(CMISSIntg), ALLOCATABLE :: FrontSurfaceNodes(:)
  INTEGER(CMISSIntg) :: BottomNormalXi,LeftNormalXi,RightNormalXi,FrontNormalXi

  LOGICAL :: EXPORT_FIELD

  INTEGER(CMISSIntg) :: shortenModelIndex!,shortenModelIndex2
  INTEGER(CMISSIntg) :: stimcomponent

!  REAL(CMISSRP) :: YVALUE
  REAL(CMISSRP) :: VALUE

  INTEGER(CMISSIntg) :: Err


  !CMISS variables

  TYPE(cmfe_BasisType) :: QuadraticBasis,LinearBasis,LinearBasisM
  TYPE(cmfe_BoundaryConditionsType) :: BoundaryConditionsM,BoundaryConditionsFE
  TYPE(cmfe_CellMLType) :: CellML
  TYPE(cmfe_CellMLEquationsType) :: CellMLEquations
  TYPE(cmfe_ControlLoopType) :: ControlLoopMain
  TYPE(cmfe_ControlLoopType) :: ControlLoopM,ControlLoopFE
  TYPE(cmfe_CoordinateSystemType) :: CoordinateSystemFE,CoordinateSystemM,WorldCoordinateSystem
  TYPE(cmfe_DecompositionType) :: DecompositionFE,DecompositionM
  TYPE(cmfe_EquationsType) :: EquationsM,EquationsFE
  TYPE(cmfe_EquationsSetType) :: EquationsSetM,EquationsSetFE
  TYPE(cmfe_FieldType) :: EquationsSetFieldM,EquationsSetFieldFE
  TYPE(cmfe_FieldType) :: GeometricFieldM,GeometricFieldFE
  TYPE(cmfe_FieldType) :: DependentFieldM,DependentFieldFE
  TYPE(cmfe_FieldType) :: IndependentFieldFE,IndependentFieldM
  TYPE(cmfe_FieldType) :: MaterialFieldM,MaterialFieldFE
  TYPE(cmfe_FieldType) :: FibreField
  TYPE(cmfe_FieldType) :: CellMLModelsField,CellMLStateField,CellMLIntermediateField,CellMLParametersField
  TYPE(cmfe_FieldsType) :: Fields
  TYPE(cmfe_GeneratedMeshType) :: GeneratedMesh
  TYPE(cmfe_MeshType) :: MeshFE,MeshM
  TYPE(cmfe_ProblemType) :: Problem
  TYPE(cmfe_RegionType) :: RegionFE,RegionM,WorldRegion
  TYPE(cmfe_SolverType) :: SolverDAE,SolverParabolic
  TYPE(cmfe_SolverType) :: SolverFE,LinearSolverFE
  TYPE(cmfe_SolverEquationsType) :: SolverEquationsM,SolverEquationsFE
  TYPE(cmfe_NodesType) :: Nodes
  TYPE(cmfe_MeshElementsType) :: QuadraticElements
  TYPE(cmfe_MeshElementsType) :: LinearElements
  TYPE(cmfe_MeshElementsType) :: ElementsM


#ifdef WIN32
  !Quickwin type
  LOGICAL :: QUICKWIN_STATUS=.FALSE.
  TYPE(WINDOWCONFIG) :: QUICKWIN_WINDOW_CONFIG
#endif
  
  !Generic CMISS variables

#ifdef WIN32
  !Initialise QuickWin
  QUICKWIN_WINDOW_CONFIG%TITLE="General Output" !Window title
  QUICKWIN_WINDOW_CONFIG%NUMTEXTROWS=-1 !Max possible number of rows
  QUICKWIN_WINDOW_CONFIG%MODE=QWIN$SCROLLDOWN
  !Set the window parameters
  QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
  !If attempt fails set with system estimated values
  IF(.NOT.QUICKWIN_STATUS) QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
#endif

!##################################################################################################################################
!##################################################################################################################################
!##################################################################################################################################

  NumberGlobalXElements=6
  NumberGlobalYElements=3
  NumberGlobalZElements=1
  
  NumberOfElementsFE=NumberGlobalXElements*NumberGlobalYElements*NumberGlobalZElements

!##################################################################################################################################
  less_info = .false.!.true.!
  if(less_info) then
    !note that the NumberOfNodesInXi1 only applies to elements in which fibres begin. Otherwise it's NumberOfNodesInXi1-1
    NumberOfNodesInXi1=50!500!240
    NumberOfNodesInXi2=2
    NumberOfNodesInXi3=1
  else
    if(NumberGlobalXElements*NumberGlobalYElements*NumberGlobalZElements==1) then
      NumberOfNodesInXi1=51
    else
      NumberOfNodesInXi1=31!500
    endif
    NumberOfNodesInXi2=2!30
    NumberOfNodesInXi3=3!45
  endif
!  NumberOfNodesPerFibre=(NumberOfNodesInXi1-1)*NumberGlobalXElements+1
!  NumberOfNodesM=NumberOfNodesPerFibre*NumberGlobalYElements*NumberGlobalZElements*NumberOfNodesInXi2*NumberOfNodesInXi3
!  NumberOfElementsM=(NumberOfNodesPerFibre-1)*NumberGlobalYElements*NumberGlobalZElements*NumberOfNodesInXi2*NumberOfNodesInXi3

!  NumberOfNodesPerFibre=NumberOfNodesInXi1
!  NumberOfNodesM=NumberOfNodesPerFibre*NumberGlobalYElements*NumberGlobalZElements*NumberOfNodesInXi2*NumberOfNodesInXi3* &
!    & NumberGlobalXElements
!  NumberOfElementsM=(NumberOfNodesPerFibre-1)*NumberGlobalYElements*NumberGlobalZElements*NumberOfNodesInXi2*NumberOfNodesInXi3* &
!    & NumberGlobalXElements

  NumberOfFibres=NumberOfNodesInXi2*NumberOfNodesInXi3*NumberGlobalYElements*NumberGlobalZElements*NumberOfInSeriesFibres
  NumberOfNodesPerFibre=(NumberOfNodesInXi1-1)*NumberGlobalXElements/NumberOfInSeriesFibres+1
  NumberOfNodesM=NumberOfNodesPerFibre*NumberOfInSeriesFibres*NumberGlobalYElements*NumberGlobalZElements*NumberOfNodesInXi2* &
    & NumberOfNodesInXi3
  NumberOfElementsM=(NumberOfNodesPerFibre-1)*NumberOfInSeriesFibres*NumberGlobalYElements*NumberGlobalZElements* &
    & NumberOfNodesInXi2*NumberOfNodesInXi3

!##################################################################################################################################
!  fast_twitch=.true.
!  if(fast_twitch) then
    pathname= "input/"
!     & "/home/heidlauf/OpenCMISS/OpenCMISS/examples/MultiPhysics/BioelectricFiniteElasticity/cellModelFiles/"
    filename=trim(pathname)//"Aliev_Panfilov_Razumova_2016_08_22.cellml"
!    filename=trim(pathname)//"Aliev_Panfilov_Razumova_slow_2016_08_01.cellml"
!   &"/home/heidlauf/OpenCMISS/opencmiss/examples/MultiPhysics/BioelectricFiniteElasticity/cellModelFiles/shorten_mod_2011_07_04.xml"
    STIM_VALUE=90.0_CMISSRP !90.0_CMISSRP
!  else !slow twitch
!    filename2= &
!  &"/home/heidlauf/OpenCMISS/opencmiss/examples/MultiPhysics/BioelectricFiniteElasticity/cellModelFiles/fast_stim_2012_07_23.xml"
!  &"/home/heidlauf/OpenCMISS/opencmiss/examples/MultiPhysics/BioelectricFiniteElasticity/cellModelFiles/slow_2012_07_23.xml_0.401"
!  &"/home/heidlauf/OpenCMISS/opencmiss/examples/MultiPhysics/BioelectricFiniteElasticity/cellModelFiles/slow_twitch_2012_01_27.xml"
!    STIM_VALUE=2000.0_CMISSRP
!  endif
!##################################################################################################################################


  !================================================================================================================================
  !  G E N E R A L   F E A T U R E S
  !================================================================================================================================

  !--------------------------------------------------------------------------------------------------------------------------------
  !Intialise OpenCMISS
  CALL cmfe_Initialise(WorldCoordinateSystem,WorldRegion,Err)

  !Trap errors
  CALL cmfe_ErrorHandlingModeSet(CMFE_ERRORS_TRAP_ERROR,Err)
  
!  CALL cmfe_DiagnosticsSetOn(CMFE_FROM_DIAG_TYPE,[1,2,3,4,5],"dignostics",["FIELD_MAPPINGS_CALCULATE"],err)
  
  !Get the computational nodes information
  CALL cmfe_ComputationalNumberOfNodesGet(NumberOfComputationalNodes,Err)
  CALL cmfe_ComputationalNodeNumberGet(ComputationalNodeNumber,Err)

  CALL cmfe_OutputSetOn("EMG",Err)
  
  NumberOfDomains=NumberOfComputationalNodes
  
  !Broadcast the number of elements in the X & Y directions and the number of partitions to the other computational nodes
  CALL MPI_BCAST(NumberGlobalXElements,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_BCAST(NumberGlobalYElements,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_BCAST(NumberGlobalZElements,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)
  CALL MPI_BCAST(NumberOfDomains,1,MPI_INTEGER,0,MPI_COMM_WORLD,MPI_IERROR)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Start the creation of a new RC coordinate system
  CALL cmfe_CoordinateSystem_Initialise(CoordinateSystemFE,Err)
  CALL cmfe_CoordinateSystem_CreateStart(CoordinateSystemUserNumberFE,CoordinateSystemFE,Err)
  !Set the coordinate system to be 3D
  CALL cmfe_CoordinateSystem_DimensionSet(CoordinateSystemFE,3,Err)
  CALL cmfe_CoordinateSystem_CreateFinish(CoordinateSystemFE,Err)


  ! CREATE A 1D COORDINATE SYSTEM
  CALL cmfe_CoordinateSystem_Initialise(CoordinateSystemM,Err)
  CALL cmfe_CoordinateSystem_CreateStart(CoordinateSystemUserNumberM,CoordinateSystemM,Err)
  !Set the coordinate system to be 1D
  CALL cmfe_CoordinateSystem_DimensionSet(CoordinateSystemM,1,Err)
  CALL cmfe_CoordinateSystem_CreateFinish(CoordinateSystemM,Err)


  !--------------------------------------------------------------------------------------------------------------------------------
  !Start the creation of the region
  CALL cmfe_Region_Initialise(RegionFE,Err)
  CALL cmfe_Region_CreateStart(RegionUserNumberFE,WorldRegion,RegionFE,Err)
  CALL cmfe_Region_CoordinateSystemSet(RegionFE,CoordinateSystemFE,Err)
  CALL cmfe_Region_LabelSet(RegionFE,"Region3D",Err)
  CALL cmfe_Region_CreateFinish(RegionFE,Err)


  ! CREATE A SECOND REGION
  CALL cmfe_Region_Initialise(RegionM,Err)
  CALL cmfe_Region_CreateStart(RegionUserNumberM,WorldRegion,RegionM,Err)
  CALL cmfe_Region_CoordinateSystemSet(RegionM,CoordinateSystemM,Err)
  CALL cmfe_Region_LabelSet(RegionM,"Region1D",Err)
  CALL cmfe_Region_CreateFinish(RegionM,Err)


  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the bases
  !Define basis functions - tri-Quadratic Lagrange 
  CALL cmfe_Basis_Initialise(QuadraticBasis,Err)
  CALL cmfe_Basis_CreateStart(QuadraticBasisUserNumber,QuadraticBasis,Err)
  CALL cmfe_Basis_TypeSet(QuadraticBasis,CMFE_BASIS_LAGRANGE_HERMITE_TP_TYPE,Err)
  CALL cmfe_Basis_NumberOfXiSet(QuadraticBasis,NumberOfXiCoordinates,Err)
  CALL cmfe_Basis_InterpolationXiSet(QuadraticBasis,[CMFE_BASIS_QUADRATIC_LAGRANGE_INTERPOLATION, &
   & CMFE_BASIS_QUADRATIC_LAGRANGE_INTERPOLATION,CMFE_BASIS_QUADRATIC_LAGRANGE_INTERPOLATION],Err)
  CALL cmfe_Basis_QuadratureNumberOfGaussXiSet(QuadraticBasis, &
   & [NumberOfGaussPoints,NumberOfGaussPoints,NumberOfGaussPoints],Err)
  CALL cmfe_Basis_CreateFinish(QuadraticBasis,Err)

  !Define basis functions - tri-Linear Lagrange
  CALL cmfe_Basis_Initialise(LinearBasis,Err)
  CALL cmfe_Basis_CreateStart(LinearBasisUserNumber,LinearBasis,Err)
  CALL cmfe_Basis_TypeSet(LinearBasis,CMFE_BASIS_LAGRANGE_HERMITE_TP_TYPE,Err)
  CALL cmfe_Basis_NumberOfXiSet(LinearBasis,NumberOfXiCoordinates,Err)
  CALL cmfe_Basis_InterpolationXiSet(LinearBasis,[CMFE_BASIS_LINEAR_LAGRANGE_INTERPOLATION, &
   & CMFE_BASIS_LINEAR_LAGRANGE_INTERPOLATION,CMFE_BASIS_LINEAR_LAGRANGE_INTERPOLATION],Err)
  CALL cmfe_Basis_QuadratureNumberOfGaussXiSet(LinearBasis, &
   & [NumberOfGaussPoints,NumberOfGaussPoints,NumberOfGaussPoints],Err)
  CALL cmfe_Basis_CreateFinish(LinearBasis,Err)


  ! CREATE A SECOND LINEAR BASIS FOR THE 1D GRID
  !Define basis functions - tri-Linear Lagrange
  CALL cmfe_Basis_Initialise(LinearBasisM,Err)
  CALL cmfe_Basis_CreateStart(LinearBasisUserNumberM,LinearBasisM,Err)
  CALL cmfe_Basis_TypeSet(LinearBasisM,CMFE_BASIS_LAGRANGE_HERMITE_TP_TYPE,Err)
  CALL cmfe_Basis_NumberOfXiSet(LinearBasisM,1,Err)
  CALL cmfe_Basis_InterpolationXiSet(LinearBasisM,[CMFE_BASIS_LINEAR_LAGRANGE_INTERPOLATION],Err)
  CALL cmfe_Basis_QuadratureNumberOfGaussXiSet(LinearBasisM,[2],Err)
  CALL cmfe_Basis_CreateFinish(LinearBasisM,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a mesh with 8 three-dimensional elements
  !Start the creation of a generated mesh in the region
  CALL cmfe_GeneratedMesh_Initialise(GeneratedMesh,Err)
  CALL cmfe_GeneratedMesh_CreateStart(GeneratedMeshUserNumber,RegionFE,GeneratedMesh,Err)
  !Set up a regular x*y*z mesh
  CALL cmfe_GeneratedMesh_TypeSet(GeneratedMesh,CMFE_GENERATED_MESH_REGULAR_MESH_TYPE,Err)
  !Set the default basis
  CALL cmfe_GeneratedMesh_BasisSet(GeneratedMesh,[QuadraticBasis,LinearBasis],Err)
  !Define the mesh on the region
  CALL cmfe_GeneratedMesh_ExtentSet(GeneratedMesh,[LENGTH,WIDTH,HEIGHT],Err)
  CALL cmfe_GeneratedMesh_NumberOfElementsSet(GeneratedMesh,[NumberGlobalXElements,NumberGlobalYElements, &
    & NumberGlobalZElements],Err)
  !Finish the creation of a generated mesh in the region
  CALL cmfe_Mesh_Initialise(MeshFE,Err)
  CALL cmfe_GeneratedMesh_CreateFinish(GeneratedMesh,MeshUserNumberFE,MeshFE,Err)
  


  ! CREATE A SECOND MESH
  !Create a mesh in the region
  CALL cmfe_Mesh_Initialise(MeshM,Err)
  CALL cmfe_Mesh_CreateStart(MeshUserNumberM,RegionM,1,MeshM,Err)
  CALL cmfe_Mesh_NumberOfComponentsSet(MeshM,1,Err)
  CALL cmfe_Mesh_NumberOfElementsSet(MeshM,NumberOfElementsM,Err)

  CALL cmfe_MeshElements_Initialise(ElementsM,Err)
  CALL cmfe_MeshElements_CreateStart(MeshM,MonodomainMeshComponentNumber,LinearBasisM,ElementsM,Err)

  !Define nodes for the mesh
  CALL cmfe_Nodes_Initialise(Nodes,Err)
  CALL cmfe_Nodes_CreateStart(RegionM,NumberOfNodesM,Nodes,Err)
  CALL cmfe_Nodes_CreateFinish(Nodes,Err)

  elem_idx=0
  DO node1=1,NumberOfNodesM
    IF(mod(node1,NumberOfNodesPerFibre)==0) CYCLE
    elem_idx=elem_idx+1
    CALL cmfe_MeshElements_NodesSet(ElementsM,elem_idx,[node1,node1+1],Err)
!    WRITE(*,*) elem_idx,node1,node1+1
  ENDDO    
  write(*,*) "Finished setting up 1D elements"


  CALL cmfe_MeshElements_CreateFinish(ElementsM,Err)
  CALL cmfe_Mesh_CreateFinish(MeshM,Err) 



  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a decomposition
  CALL cmfe_Decomposition_Initialise(DecompositionFE,Err)
  CALL cmfe_Decomposition_CreateStart(DecompositionUserNumberFE,MeshFE,DecompositionFE,Err)

  IF(NumberOfDomains>1) THEN
    CALL cmfe_Decomposition_TypeSet(DecompositionFE,CMFE_DECOMPOSITION_USER_DEFINED_TYPE,Err)
    elem_idx2=0
    DO domain_idx=0,NumberOfDomains-1
      DO elem_idx=1,NumberOfElementsFE/NumberOfDomains
        elem_idx2=elem_idx2+1
        CALL cmfe_Decomposition_ElementDomainSet(DecompositionFE,elem_idx2,domain_idx,Err)
      ENDDO
    ENDDO       
    CALL cmfe_Decomposition_NumberOfDomainsSet(DecompositionFE,NumberOfDomains,Err)
  ELSE
    CALL cmfe_Decomposition_TypeSet(DecompositionFE,CMFE_DECOMPOSITION_CALCULATED_TYPE,Err)
    CALL cmfe_Decomposition_NumberOfDomainsSet(DecompositionFE,NumberOfDomains,Err)
  ENDIF
  CALL cmfe_Decomposition_CalculateFacesSet(DecompositionFE,.TRUE.,Err)
  CALL cmfe_Decomposition_CreateFinish(DecompositionFE,Err)

  ! CREATE A SECOND DECOMPOSITION
  CALL cmfe_Decomposition_Initialise(DecompositionM,Err)
  CALL cmfe_Decomposition_CreateStart(DecompositionUserNumberM,MeshM,DecompositionM,Err)
  IF(NumberOfDomains>1) THEN
    CALL cmfe_Decomposition_TypeSet(DecompositionM,CMFE_DECOMPOSITION_USER_DEFINED_TYPE,Err)
    elem_idx2=0
    DO domain_idx=0,NumberOfDomains-1
      DO elem_idx=1,NumberOfElementsFE/NumberOfDomains/NumberGlobalXElements
        DO i=1,NumberOfNodesInXi3
          DO j=1,NumberOfNodesInXi2
            DO k=1,NumberOfNodesPerFibre-1
              elem_idx2=elem_idx2+1
              CALL cmfe_Decomposition_ElementDomainSet(DecompositionM,elem_idx2,domain_idx,Err)
            ENDDO
          ENDDO
        ENDDO
      ENDDO
    ENDDO

    IF(elem_idx2/=NumberOfElementsM) THEN
      WRITE(*,*) "Error in setting up the decomposition for monodomain!"
      STOP
    ENDIF

    CALL cmfe_Decomposition_NumberOfDomainsSet(DecompositionM,NumberOfDomains,Err)
  ELSE
    CALL cmfe_Decomposition_TypeSet(DecompositionM,CMFE_DECOMPOSITION_CALCULATED_TYPE,Err)
    CALL cmfe_Decomposition_NumberOfDomainsSet(DecompositionM,NumberOfDomains,Err)
  ENDIF
  CALL cmfe_Decomposition_CreateFinish(DecompositionM,Err)


  !================================================================================================================================
  !  F I N I T E   E L A S T C I T Y
  !================================================================================================================================
  
  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a geometric field for finite elasticity - quadratic interpolation
  CALL cmfe_Field_Initialise(GeometricFieldFE,Err)
  CALL cmfe_Field_CreateStart(FieldGeometryUserNumberFE,RegionFE,GeometricFieldFE,Err)
  CALL cmfe_Field_TypeSet(GeometricFieldFE,CMFE_FIELD_GEOMETRIC_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(GeometricFieldFE,DecompositionFE,Err)
  CALL cmfe_Field_NumberOfVariablesSet(GeometricFieldFE,FieldGeometryNumberOfVariables,Err)
  CALL cmfe_Field_NumberOfComponentsSet(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,FieldGeometryNumberOfComponents,Err)  
  CALL cmfe_Field_ComponentMeshComponentSet(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,2,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,3,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_VariableLabelSet(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,"Geometry",Err)
  CALL cmfe_Field_CreateFinish(GeometricFieldFE,Err)

!  CALL cmfe_Field_ParameterSetUpdateStart(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,Err)
!  CALL cmfe_Field_ParameterSetUpdateFinish(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,Err)
  CALL cmfe_GeneratedMesh_GeometricParametersCalculate(GeneratedMesh,GeometricFieldFE,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a fibre field and attach it to the geometric field - quadratic interpolation
  CALL cmfe_Field_Initialise(FibreField,Err)
  CALL cmfe_Field_CreateStart(FieldFibreUserNumber,RegionFE,FibreField,Err)
  CALL cmfe_Field_TypeSet(FibreField,CMFE_FIELD_FIBRE_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(FibreField,DecompositionFE,Err)
  CALL cmfe_Field_GeometricFieldSet(FibreField,GeometricFieldFE,Err)
  CALL cmfe_Field_NumberOfVariablesSet(FibreField,FieldFibreNumberOfVariables,Err)
  CALL cmfe_Field_NumberOfComponentsSet(FibreField,CMFE_FIELD_U_VARIABLE_TYPE,FieldFibreNumberOfComponents,Err)  
  CALL cmfe_Field_ComponentMeshComponentSet(FibreField,CMFE_FIELD_U_VARIABLE_TYPE,1,QuadraticMeshComponentNumber,Err) 
  CALL cmfe_Field_ComponentMeshComponentSet(FibreField,CMFE_FIELD_U_VARIABLE_TYPE,2,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(FibreField,CMFE_FIELD_U_VARIABLE_TYPE,3,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_VariableLabelSet(FibreField,CMFE_FIELD_U_VARIABLE_TYPE,"Fibre",Err)
  CALL cmfe_Field_CreateFinish(FibreField,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a material field for Finite Elasticity and attach it to the geometric field - quadratic interpolation
  CALL cmfe_Field_Initialise(MaterialFieldFE,Err)
  CALL cmfe_Field_CreateStart(FieldMaterialUserNumberFE,RegionFE,MaterialFieldFE,Err)
  CALL cmfe_Field_TypeSet(MaterialFieldFE,CMFE_FIELD_MATERIAL_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(MaterialFieldFE,DecompositionFE,Err)
  CALL cmfe_Field_GeometricFieldSet(MaterialFieldFE,GeometricFieldFE,Err)
  CALL cmfe_Field_NumberOfVariablesSet(MaterialFieldFE,FieldMaterialNumberOfVariablesFE,Err)
  CALL cmfe_Field_VariableTypesSet(MaterialFieldFE,[CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_V_VARIABLE_TYPE],Err)
  CALL cmfe_Field_NumberOfComponentsSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,8,Err)
  CALL cmfe_Field_NumberOfComponentsSet(MaterialFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,1,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,2,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,3,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,4,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,5,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,6,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,7,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,8,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,1,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_VariableLabelSet(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,"MaterialFE",Err)
  CALL cmfe_Field_VariableLabelSet(MaterialFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,"Gravity",Err)
  CALL cmfe_Field_CreateFinish(MaterialFieldFE,Err)

  !Set Material-Parameters [mu(1) mu(2) mu(3) alpha(1) alpha(2) alpha(3) mu_0]
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,C(1),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2,C(2),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3,C(3),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,4,C(4),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,5,C(5),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,6,C(6),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,7,C(7),Err)
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,8,C(8),Err)
!  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,0.0_CMISSRP,Err)


  !Create the dependent field for FE with 2 variables and * components 
  !  3-d: 3 displacement (quad interpol), 1 pressure (lin interpol) --> * = 4
  !  2-d: 2 displacement (quad interpol), 1 pressure (lin interpol) --> * = 3
  !  1-d: 1 displacement (quad interpol), 1 pressure (lin interpol) --> * = 2
  CALL cmfe_Field_Initialise(DependentFieldFE,Err)
  CALL cmfe_Field_CreateStart(FieldDependentUserNumberFE,RegionFE,DependentFieldFE,Err)
  CALL cmfe_Field_TypeSet(DependentFieldFE,CMFE_FIELD_GEOMETRIC_GENERAL_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(DependentFieldFE,DecompositionFE,Err)
  CALL cmfe_Field_GeometricFieldSet(DependentFieldFE,GeometricFieldFE,Err)
  CALL cmfe_Field_DependentTypeSet(DependentFieldFE,CMFE_FIELD_DEPENDENT_TYPE,Err)
  CALL cmfe_Field_NumberOfVariablesSet(DependentFieldFE,FieldDependentNumberOfVariablesFE,Err)
  CALL cmfe_Field_VariableTypesSet(DependentFieldFE,[CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE],Err)
  CALL cmfe_Field_NumberOfComponentsSet(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,FieldDependentNumberOfComponentsFE,Err)
  CALL cmfe_Field_NumberOfComponentsSet(DependentFieldFE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,FieldDependentNumberOfComponentsFE,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,2,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,3,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,4,LinearMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,1,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,2,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,3,QuadraticMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldFE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,4,LinearMeshComponentNumber,Err)
!  CALL cmfe_Field_ScalingTypeSet(DependentFieldFE,CMFE_FIELD_UNIT_SCALING,Err)
  CALL cmfe_Field_VariableLabelSet(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,"DependentFE",Err)
  CALL cmfe_Field_VariableLabelSet(DependentFieldFE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,"Reaction_Force",Err)
  CALL cmfe_Field_CreateFinish(DependentFieldFE,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the independent field for the active stress in the mechanics mesh
!  independent_field_auto_create = .TRUE.
  CALL cmfe_Field_Initialise(IndependentFieldFE,Err)
  IF(.NOT. independent_field_auto_create) THEN
    CALL cmfe_Field_CreateStart(FieldIndependentUserNumberFE,RegionFE,IndependentFieldFE,Err)
    CALL cmfe_Field_TypeSet(IndependentFieldFE,CMFE_FIELD_GENERAL_TYPE,Err)
    CALL cmfe_Field_MeshDecompositionSet(IndependentFieldFE,DecompositionFE,Err)
    CALL cmfe_Field_GeometricFieldSet(IndependentFieldFE,GeometricFieldFE,Err)
    CALL cmfe_Field_DependentTypeSet(IndependentFieldFE,CMFE_FIELD_INDEPENDENT_TYPE,Err)
    CALL cmfe_Field_NumberOfVariablesSet(IndependentFieldFE,2,Err)
    CALL cmfe_Field_VariableTypesSet(IndependentFieldFE,[CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_V_VARIABLE_TYPE],Err)
    CALL cmfe_Field_NumberOfComponentsSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,5,Err)
    CALL cmfe_Field_NumberOfComponentsSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,4,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1, &
     & CMFE_FIELD_GAUSS_POINT_BASED_INTERPOLATION,Err) !A_1
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,2, &
     & CMFE_FIELD_GAUSS_POINT_BASED_INTERPOLATION,Err) !A_2
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,3, &
     & CMFE_FIELD_GAUSS_POINT_BASED_INTERPOLATION,Err) !x_1
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,4, &
     & CMFE_FIELD_GAUSS_POINT_BASED_INTERPOLATION,Err) !x_2
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,5, &
     & CMFE_FIELD_GAUSS_POINT_BASED_INTERPOLATION,Err) !lambda_a
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,1, &
     & CMFE_FIELD_ELEMENT_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,2, &
     & CMFE_FIELD_ELEMENT_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,3, &
     & CMFE_FIELD_ELEMENT_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,4, &
     & CMFE_FIELD_ELEMENT_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentMeshComponentSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,QuadraticMeshComponentNumber,Err)
    CALL cmfe_Field_DataTypeSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_DP_TYPE,Err)
    CALL cmfe_Field_DataTypeSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_INTG_TYPE,Err)
    CALL cmfe_Field_VariableLabelSet(IndependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,"XB_state_variables_FE",Err)
    CALL cmfe_Field_VariableLabelSet(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,"subgrid_info",Err)
    CALL cmfe_Field_CreateFinish(IndependentFieldFE,Err)
  ENDIF


  !================================================================================================================================
  !  M O N O D O M A I N
  !================================================================================================================================
  
  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a geometric field for monodomain - quadratic interpolation
  CALL cmfe_Field_Initialise(GeometricFieldM,Err)
  CALL cmfe_Field_CreateStart(FieldGeometryUserNumberM,RegionM,GeometricFieldM,Err)
  CALL cmfe_Field_TypeSet(GeometricFieldM,CMFE_FIELD_GEOMETRIC_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(GeometricFieldM,DecompositionM,Err)
  CALL cmfe_Field_TypeSet(GeometricFieldM,CMFE_FIELD_GEOMETRIC_TYPE,Err)
  CALL cmfe_Field_NumberOfVariablesSet(GeometricFieldM,1,Err)
  CALL cmfe_Field_NumberOfComponentsSet(GeometricFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,Err)
  CALL cmfe_Field_VariableLabelSet(GeometricFieldM,CMFE_FIELD_U_VARIABLE_TYPE,"GeometryM",Err)
  CALL cmfe_Field_CreateFinish(GeometricFieldM,Err)



  !--------------------------------------------------------------------------------------------------------------------------------
  !Create a materials field for monodomain and attach it to the geometric field - constant interpolation
  CALL cmfe_Field_Initialise(MaterialFieldM,Err)
  CALL cmfe_Field_CreateStart(FieldMaterialUserNumberM,RegionM,MaterialFieldM,Err)
  CALL cmfe_Field_TypeSet(MaterialFieldM,CMFE_FIELD_MATERIAL_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(MaterialFieldM,DecompositionM,Err)
  CALL cmfe_Field_GeometricFieldSet(MaterialFieldM,GeometricFieldM,Err)
  CALL cmfe_Field_NumberOfVariablesSet(MaterialFieldM,FieldMaterialNumberOfVariablesM,Err)
  CALL cmfe_Field_NumberOfComponentsSet(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,FieldMaterialNumberOfComponentsM,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,2,CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
  CALL cmfe_Field_ComponentInterpolationSet(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,3,CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
  CALL cmfe_Field_VariableLabelSet(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,"MaterialM",Err)
  CALL cmfe_Field_CreateFinish(MaterialFieldM,Err)
  !Set Am
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,Am,Err)
  !Set Cm
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2,Cm_fast,Err)
  !Set Conductivity
  CALL cmfe_Field_ComponentValuesInitialise(MaterialFieldM,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3, &
   & CONDUCTIVITY,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the dependent field for monodomain with 3 variables. [U: 1 component, DelUdelN: 1 component, V: 3]
  CALL cmfe_Field_Initialise(DependentFieldM,Err)
  CALL cmfe_Field_CreateStart(FieldDependentUserNumberM,RegionM,DependentFieldM,Err)
  CALL cmfe_Field_TypeSet(DependentFieldM,CMFE_FIELD_GENERAL_TYPE,Err)
  CALL cmfe_Field_MeshDecompositionSet(DependentFieldM,DecompositionM,Err)
  CALL cmfe_Field_GeometricFieldSet(DependentFieldM,GeometricFieldM,Err)
  CALL cmfe_Field_DependentTypeSet(DependentFieldM,CMFE_FIELD_DEPENDENT_TYPE,Err)
  CALL cmfe_Field_NumberOfVariablesSet(DependentFieldM,FieldDependentNumberOfVariablesM,Err)
  CALL cmfe_Field_VariableTypesSet(DependentFieldM,[CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_DELUDELN_VARIABLE_TYPE, &
   & CMFE_FIELD_V_VARIABLE_TYPE],Err)
  CALL cmfe_Field_NumberOfComponentsSet(DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,Err)
  CALL cmfe_Field_NumberOfComponentsSet(DependentFieldM,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,1,Err)
  !additional the V_Var_Type with 3 components for the 3-d position of the geometry
  CALL cmfe_Field_NumberOfComponentsSet(DependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,3,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,MonodomainMeshComponentNumber,Err)
  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldM,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,1,MonodomainMeshComponentNumber,Err)
!  CALL cmfe_Field_ComponentMeshComponentSet(DependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,1,MonodomainMeshComponentNumber,Err)
  CALL cmfe_Field_DimensionSet(DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_SCALAR_DIMENSION_TYPE,Err)
  CALL cmfe_Field_DimensionSet(DependentFieldM,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,CMFE_FIELD_SCALAR_DIMENSION_TYPE,Err)
  CALL cmfe_Field_VariableLabelSet(DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,"Vm",Err)
  CALL cmfe_Field_VariableLabelSet(DependentFieldM,CMFE_FIELD_DELUDELN_VARIABLE_TYPE,"dVm/dn",Err)
  CALL cmfe_Field_VariableLabelSet(DependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,"GeometryM3D",Err)
  CALL cmfe_Field_CreateFinish(DependentFieldM,Err)


  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the independent field for the active stress in the bioelectrics mesh
!  independent_field_auto_create = .TRUE.
  CALL cmfe_Field_Initialise(IndependentFieldM,Err)
  IF(.NOT. independent_field_auto_create) THEN
    CALL cmfe_Field_CreateStart(FieldIndependentUserNumberM,RegionM,IndependentFieldM,Err)
    CALL cmfe_Field_TypeSet(IndependentFieldM,CMFE_FIELD_GENERAL_TYPE,Err)
    CALL cmfe_Field_MeshDecompositionSet(IndependentFieldM,DecompositionM,Err)
    CALL cmfe_Field_GeometricFieldSet(IndependentFieldM,GeometricFieldM,Err)
    CALL cmfe_Field_DependentTypeSet(IndependentFieldM,CMFE_FIELD_INDEPENDENT_TYPE,Err)
    CALL cmfe_Field_NumberOfVariablesSet(IndependentFieldM,4,Err)
    CALL cmfe_Field_VariableTypesSet(IndependentFieldM,[CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_V_VARIABLE_TYPE, &
     & CMFE_FIELD_U1_VARIABLE_TYPE,CMFE_FIELD_U2_VARIABLE_TYPE],Err)
    
    !first variable:   CMFE_FIELD_U_VARIABLE_TYPE
    CALL cmfe_Field_DataTypeSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_DP_TYPE,Err)
    CALL cmfe_Field_NumberOfComponentsSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,4,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err) !A_1
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,2, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err) !A_2
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,3, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err) !x_1
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,4, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err) !x_2
    CALL cmfe_Field_VariableLabelSet(IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,"XB_state_variables_M",Err)

    !second variable:   CMFE_FIELD_V_VARIABLE_TYPE -- 1) motor unit number   2) fibre type   3) fibre number   4) nearest Gauss point   5) in element number (LOCAL NODE NUMBERING!!!)
    CALL cmfe_Field_DataTypeSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_INTG_TYPE,Err)
    CALL cmfe_Field_NumberOfComponentsSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,FieldIndependentNumberOfComponentsM2,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,1, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,2, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,3, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,4, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,5, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_VariableLabelSet(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,"fibre_info",Err)

    !third variable:   FIELD_U1_VARIABLE_TYPE -- 1) half-sarcomere length   2) inital half-sarcomere length   3) initial node distance
    CALL cmfe_Field_DataTypeSet(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,CMFE_FIELD_DP_TYPE,Err)
    CALL cmfe_Field_NumberOfComponentsSet(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,3,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,1, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,2, &
     & CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,3, &
     & CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
    CALL cmfe_Field_VariableLabelSet(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,"half-sarcomere_length",Err)

    !fourth variable:   FIELD_U2_VARIABLE_TYPE -- 1) old node distance   2) maximum contraction velocity   3) relative contraction velocity   4) velocity before 1 time step   5) velocity before 2 time step   6) velocity before 3 time steps
    CALL cmfe_Field_DataTypeSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,CMFE_FIELD_DP_TYPE,Err)
    CALL cmfe_Field_NumberOfComponentsSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,6,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,1, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,2, &
     & CMFE_FIELD_CONSTANT_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,3, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,4, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,5, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_ComponentInterpolationSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,6, &
     & CMFE_FIELD_NODE_BASED_INTERPOLATION,Err)
    CALL cmfe_Field_VariableLabelSet(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,"contraction_velocity",Err)

    CALL cmfe_Field_CreateFinish(IndependentFieldM,Err)
  ENDIF
  

  
  !================================================================================================================================
  !  EQUATIONS SET

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the equations_set for Finite Elasticity
  CALL cmfe_Field_Initialise(EquationsSetFieldFE,Err)
  CALL cmfe_EquationsSet_Initialise(EquationsSetFE,Err)
  CALL cmfe_EquationsSet_CreateStart(EquationsSetsUserNumberFE,RegionFE,FibreField,[CMFE_EQUATIONS_SET_ELASTICITY_CLASS, &
   & CMFE_EQUATIONS_SET_FINITE_ELASTICITY_TYPE,CMFE_EQUATIONS_SET_1D3D_MONODOMAIN_ACTIVE_STRAIN_SUBTYPE], & 
   & EquationsSetFieldUserNumberFE,EquationsSetFieldFE,EquationsSetFE,Err)
  CALL cmfe_EquationsSet_CreateFinish(EquationsSetFE,Err)

  !Create the equations set dependent field variables for Finite Elasticity
  CALL cmfe_EquationsSet_DependentCreateStart(EquationsSetFE,FieldDependentUserNumberFE,DependentFieldFE,Err)
  CALL cmfe_EquationsSet_DependentCreateFinish(EquationsSetFE,Err)

  !Create the equations set independent field variable for the active stress component for Finite Elasticity
  CALL cmfe_EquationsSet_IndependentCreateStart(EquationsSetFE,FieldIndependentUserNumberFE,IndependentFieldFE,Err)
  CALL cmfe_EquationsSet_IndependentCreateFinish(EquationsSetFE,Err)

  !Create the equations set materials field variables for Finite Elasticity
  CALL cmfe_EquationsSet_MaterialsCreateStart(EquationsSetFE,FieldMaterialUserNumberFE,MaterialFieldFE,Err)  
  CALL cmfe_EquationsSet_MaterialsCreateFinish(EquationsSetFE,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the equations_set for monodomain
  CALL cmfe_Field_Initialise(EquationsSetFieldM,Err)
  CALL cmfe_EquationsSet_Initialise(EquationsSetM,Err)
  !Set the equations set to be a Monodomain equations set
  !> \todo solve the monodomain problem on the fibre field rather than on the geometric field: GeometricField <--> FibreField
  CALL cmfe_EquationsSet_CreateStart(EquationsSetsUserNumberM,RegionM,GeometricFieldM,[CMFE_EQUATIONS_SET_BIOELECTRICS_CLASS, &
   & CMFE_EQUATIONS_SET_MONODOMAIN_EQUATION_TYPE,CMFE_EQUATIONS_SET_1D3D_MONODOMAIN_ACTIVE_STRAIN_SUBTYPE], &
   & EquationsSetFieldUserNumberM,EquationsSetFieldM,EquationsSetM,Err)
  CALL cmfe_EquationsSet_CreateFinish(EquationsSetM,Err)

  !Create the equations set dependent field variables for monodomain
  CALL cmfe_EquationsSet_DependentCreateStart(EquationsSetM,FieldDependentUserNumberM,DependentFieldM,Err)
  CALL cmfe_EquationsSet_DependentCreateFinish(EquationsSetM,Err)

  !Create the equations set independent field variable for the active stress component for Finite Elasticity
  CALL cmfe_EquationsSet_IndependentCreateStart(EquationsSetM,FieldIndependentUserNumberM,IndependentFieldM,Err)
  CALL cmfe_EquationsSet_IndependentCreateFinish(EquationsSetM,Err)

  !Create the equations set materials field variables for monodomain
  CALL cmfe_EquationsSet_MaterialsCreateStart(EquationsSetM,FieldMaterialUserNumberM,MaterialFieldM,Err)
  CALL cmfe_EquationsSet_MaterialsCreateFinish(EquationsSetM,Err)

 
 
  !UPDATE THE INDEPENDENT FIELD IndependentFieldM
  !first variable
  !  components: 
  !    1) A_1
  !    2) A_2
  !    3) x_1
  !    4) x_2
  !
  !second variable
  !  components: 
  !    1) motor unit number
  !    2) fibre type
  !    3) fibre number
  !    4) nearest Gauss point
  !    5) in element number (LOCAL NODE NUMBERING!!!)
  !
  !init the motor unit number to 101
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,101,Err) !  

  !--------------------------------------------------------------------------------------------------------------------------------
  !Read in the MU fibre distribution
  allocate(mu_distri(NumberOfNodesInXi2*NumberOfNodesInXi3*NumberGlobalYElements*NumberGlobalZElements))
  !the MU number the fiber belongs to
  open(unit=7,file="input/MU_fibre_distribution_4050.txt",action="read",iostat=stat)
  read(7,*,iostat=stat) mu_distri(:)
  close(unit=7)
  write(*,*) "Finished reading file: input/MU_fibre_distribution_4050.txt"

  k=0
  do i=1,NumberOfNodesInXi2*NumberOfNodesInXi3*NumberGlobalYElements*NumberGlobalZElements
    mu_nr=mu_distri(i)
    do j=1,NumberOfNodesPerFibre
      k=k+1
      CALL cmfe_Field_ParameterSetUpdateNode(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,1, &
       & k,1,mu_nr,Err)
    enddo
  enddo

  !init the fibre type to 1
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2,1,Err) !Ftype=1
  !init the fibre number, the nearest Gauss point info and the inElem info to 0
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3,0,Err)
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,4,0,Err)
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,5,0,Err) !(LOCAL NODE NUMBERING!!!)
  !third variable:
  !  components:
  !    1) half-sarcomere length
  !    2) initial half-sarcomere length
  !    3) initial node distance
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2, &
   & 1.0_CMISSRP,Err) ! lengths in the cell model are in /micro/meters!!!
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3, &
   & LENGTH/(NumberOfInSeriesFibres*NumberOfNodesPerFibre-1),Err)  !lengths in the cell model are in /micro/meters!!!
  !fourth variable:
  !  components:
  !    1) old node distance
  !    2) maximum contraction velocity
  !    3) relative contraction velocity
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1, &
   & LENGTH/(NumberOfInSeriesFibres*NumberOfNodesPerFibre-1),Err)  !lengths in the cell model are in /micro/meters!!!
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2, &
   & Vmax/(NumberOfInSeriesFibres*NumberOfNodesPerFibre-1),Err)    !velocity in the cell model is in micro/meters/millisecond!!!
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3, &
   & 0.0_CMISSRP,Err)    !velocity in the cell model is in /micro/meters/per/millisecond!!!


  !UPDATE THE INDEPENDENT FIELD IndependentFieldFE
  !second variable of IndependentFieldFE
  !  components:
  !    1) number of nodes in Xi(1) direction per element
  !    2) number of nodes in Xi(2) direction per element
  !    3) number of nodes in Xi(3) direction per element
  !    4) beginning of fibres in this FE element??? 1=yes, 0=no
  !
  !initialise as if the fibres would not start in any element, and adjust below
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1, &
   & NumberOfNodesInXi1-1,Err)
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2, &
   & NumberOfNodesInXi2,Err)
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3, &
   & NumberOfNodesInXi3,Err)
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,4, &
   & 0,Err)

  !fibres are starting in elements 1,4,7,10,...
  DO elem_idx=1,NumberOfElementsFE,NumberGlobalXElements/NumberOfInSeriesFibres
    CALL cmfe_Decomposition_ElementDomainGet(DecompositionFE,elem_idx,ElementDomain,Err)
    IF(ElementDomain==ComputationalNodeNumber) THEN
      !fibres begin in this element
      CALL cmfe_Field_ParameterSetUpdateElement(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE, &
       & elem_idx,4,1,Err) 
      CALL cmfe_Field_ParameterSetUpdateElement(IndependentFieldFE,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE, &
       & elem_idx,1,NumberOfNodesInXi1,Err)
    ENDIF
  ENDDO

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the equations set equations for monodomain
  CALL cmfe_Equations_Initialise(EquationsM,Err)
  CALL cmfe_EquationsSet_EquationsCreateStart(EquationsSetM,EquationsM,Err)
  CALL cmfe_Equations_SparsityTypeSet(EquationsM,CMFE_EQUATIONS_SPARSE_MATRICES,Err)
  CALL cmfe_Equations_OutputTypeSet(EquationsM,CMFE_EQUATIONS_NO_OUTPUT,Err)
  !CALL cmfe_Equations_OutputTypeSet(Equations,CMFE_EQUATIONS_TIMING_OUTPUT,Err)
  !CALL cmfe_Equations_OutputTypeSet(Equations,CMFE_EQUATIONS_MATRIX_OUTPUT,Err)
  !CALL cmfe_Equations_OutputTypeSet(Equations,CMFE_EQUATIONS_ELEMENT_MATRIX_OUTPUT,Err)
  CALL cmfe_EquationsSet_EquationsCreateFinish(EquationsSetM,Err)

  !Create the equations set equations for Finite Elasticity
  CALL cmfe_Equations_Initialise(EquationsFE,Err)
  CALL cmfe_EquationsSet_EquationsCreateStart(EquationsSetFE,EquationsFE,Err)
  CALL cmfe_Equations_SparsityTypeSet(EquationsFE,CMFE_EQUATIONS_SPARSE_MATRICES,Err)
  CALL cmfe_Equations_OutputTypeSet(EquationsFE,CMFE_EQUATIONS_NO_OUTPUT,Err)
  CALL cmfe_EquationsSet_EquationsCreateFinish(EquationsSetFE,Err)


  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the CellML environment
  CALL cmfe_CellML_Initialise(CellML,Err)
  CALL cmfe_CellML_CreateStart(CellMLUserNumber,RegionM,CellML,Err)
  !Import the Shorten et al. 2007 model from a file
  CALL cmfe_CellML_ModelImport(CellML,filename,shortenModelIndex,Err)
!  CALL cmfe_CellML_ModelImport(CellML,filename2,shortenModelIndex2,Err)
  ! Now we have imported all the models we are able to specify which variables from the model we want:
  !,- to set from this side
  CALL cmfe_CellML_VariableSetAsKnown(CellML,shortenModelIndex,"Aliev_Panfilov/I_HH",Err)
  CALL cmfe_CellML_VariableSetAsKnown(CellML,shortenModelIndex,"Razumova/l_hs",Err)
  CALL cmfe_CellML_VariableSetAsKnown(CellML,shortenModelIndex,"Razumova/velo",Err)
!
!  CALL cmfe_CellML_VariableSetAsKnown(CellML,shortenModelIndex2,"wal_environment/I_HH",Err)
!  CALL cmfe_CellML_VariableSetAsKnown(CellML,shortenModelIndex2,"razumova/L_S",Err)
!  CALL cmfe_CellML_VariableSetAsKnown(CellML,shortenModelIndex2,"razumova/rel_velo",Err)
  !,- to get from the CellML side
!  CALL cmfe_CellML_VariableSetAsWanted(CellML,shortenModelIndex,"wal_environment/I_T",Err)
!  CALL cmfe_CellML_VariableSetAsWanted(CellML,shortenModelIndex,"wal_environment/I_ionic_s",Err)
!  CALL cmfe_CellML_VariableSetAsWanted(CellML,shortenModelIndex,"wal_environment/I_ionic_t",Err)
  !
  !NOTE: If an INTERMEDIATE (or ALGEBRAIC) variable should be used in a mapping, it has to be set as known or wanted first!
  !,  --> set "razumova/stress" as wanted!
  !,  --> no need to set "wal_environment/vS" since all STATE variables are automatically set as wanted! 
!  CALL cmfe_CellML_VariableSetAsWanted(CellML,shortenModelIndex,"razumova/stress",Err)
!  CALL cmfe_CellML_VariableSetAsWanted(CellML,shortenModelIndex2,"razumova/stress",Err)
  !,- and override constant parameters without needing to set up fields
  !> \todo Need to allow parameter values to be overridden for the case when user has non-spatially varying parameter value.
  !Finish the CellML environment
  CALL cmfe_CellML_CreateFinish(CellML,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the CellML <--> OpenCMISS field maps
  CALL cmfe_CellML_FieldMapsCreateStart(CellML,Err)
  !Map the half-sarcomere length L_S
  CALL cmfe_CellML_CreateFieldToCellMLMap(CellML,IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE, &
   & shortenModelIndex,"Razumova/l_hs",CMFE_FIELD_VALUES_SET_TYPE,Err)
  !Map the sarcomere relative contraction velocity
  CALL cmfe_CellML_CreateFieldToCellMLMap(CellML,IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,3,CMFE_FIELD_VALUES_SET_TYPE, &
   & shortenModelIndex,"Razumova/velo",CMFE_FIELD_VALUES_SET_TYPE,Err)
  !Map the transmembrane voltage V_m
  CALL cmfe_CellML_CreateFieldToCellMLMap(CellML,DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE, &
   & shortenModelIndex,"Aliev_Panfilov/V_m",CMFE_FIELD_VALUES_SET_TYPE,Err)
  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex,"Aliev_Panfilov/V_m",CMFE_FIELD_VALUES_SET_TYPE, &
   & DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE,Err)
  !Map the active stress
  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex,"Razumova/A_1",CMFE_FIELD_VALUES_SET_TYPE, &
   & IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE,Err)
  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex,"Razumova/A_2",CMFE_FIELD_VALUES_SET_TYPE, &
   & IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,2,CMFE_FIELD_VALUES_SET_TYPE,Err)
  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex,"Razumova/x_1",CMFE_FIELD_VALUES_SET_TYPE, &
   & IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,3,CMFE_FIELD_VALUES_SET_TYPE,Err)
  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex,"Razumova/x_2",CMFE_FIELD_VALUES_SET_TYPE, &
   & IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,4,CMFE_FIELD_VALUES_SET_TYPE,Err)

!  CALL cmfe_CellML_CreateFieldToCellMLMap(CellML,IndependentFieldM,CMFE_FIELD_U1_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE, &
!   & shortenModelIndex2,"razumova/L_S",CMFE_FIELD_VALUES_SET_TYPE,Err)
!  !Map the sarcomere relative contraction velocity
!  CALL cmfe_CellML_CreateFieldToCellMLMap(CellML,IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,3,CMFE_FIELD_VALUES_SET_TYPE, &
!   & shortenModelIndex2,"razumova/rel_velo",CMFE_FIELD_VALUES_SET_TYPE,Err)
!  !Map the transmembrane voltage V_m
!  CALL cmfe_CellML_CreateFieldToCellMLMap(CellML,DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE, &
!   & shortenModelIndex2,"wal_environment/vS",CMFE_FIELD_VALUES_SET_TYPE,Err)
!  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex2,"wal_environment/vS",CMFE_FIELD_VALUES_SET_TYPE, &
!   & DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE,Err)
!  !Map the active stress
!  CALL cmfe_CellML_CreateCellMLToFieldMap(CellML,shortenModelIndex2,"razumova/stress",CMFE_FIELD_VALUES_SET_TYPE, &
!   & IndependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,1,CMFE_FIELD_VALUES_SET_TYPE,Err)

  CALL cmfe_CellML_FieldMapsCreateFinish(CellML,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Initialise dependent field for monodomain
  !> \todo - get V_m initialial value.
  CALL cmfe_Field_ComponentValuesInitialise(DependentFieldM,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1, &
   & 0.0_CMISSRP,Err)
  
  !Initialise dependent field for Finite Elasticity from undeformed geometry and set hydrostatic pressure
  CALL cmfe_Field_ParametersToFieldParametersComponentCopy(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE, &
   & CMFE_FIELD_VALUES_SET_TYPE,1,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,Err)
  CALL cmfe_Field_ParametersToFieldParametersComponentCopy(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE, & 
   & CMFE_FIELD_VALUES_SET_TYPE,2,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,2,Err)
  CALL cmfe_Field_ParametersToFieldParametersComponentCopy(GeometricFieldFE,CMFE_FIELD_U_VARIABLE_TYPE, &
   & CMFE_FIELD_VALUES_SET_TYPE,3,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3,Err)
!  INIT_PRESSURE=-2.0_CMISSRP*MAT_FE(2)-MAT_FE(1)
  CALL cmfe_Field_ComponentValuesInitialise(DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,4, & 
!   & INIT_PRESSURE,Err)
   & 0.0_CMISSRP,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the CellML models field
  CALL cmfe_Field_Initialise(CellMLModelsField,Err)
  CALL cmfe_CellML_ModelsFieldCreateStart(CellML,CellMLModelsFieldUserNumber,CellMLModelsField,Err)
  CALL cmfe_CellML_ModelsFieldCreateFinish(CellML,Err)

  !Set up the models field
  CALL cmfe_Field_ComponentValuesInitialise(CellMLModelsField,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1, &
   & shortenModelIndex,Err)

!  DO NodeNumber=NumberOfNodesPerFibre/2,NumberOfNodesM,NumberOfNodesPerFibre
!    CALL cmfe_Decomposition_NodeDomainGet(DecompositionM,NodeNumber,1,NodeDomain,Err)
!    IF(NodeDomain==ComputationalNodeNumber) THEN
!      CALL cmfe_Field_ParameterSetUpdateNode(CellMLModelsField,CMFE_FIELD_U_VARIABLE_TYPE, &
!        & CMFE_FIELD_VALUES_SET_TYPE,1,1,NodeNumber,1,shortenModelIndex2,Err)
!    ENDIF
!  ENDDO

!  CALL cmfe_Field_ParameterSetUpdateStart(CellMLModelsField,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,Err)
!  CALL cmfe_Field_ParameterSetUpdateFinish(CellMLModelsField,CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,Err)


  !Create the CellML state field
  CALL cmfe_Field_Initialise(CellMLStateField,Err)
  CALL cmfe_CellML_StateFieldCreateStart(CellML,CellMLStateFieldUserNumber,CellMLStateField,Err)
  CALL cmfe_CellML_StateFieldCreateFinish(CellML,Err)

!  !Create the CellML intermediate field
!  CALL cmfe_Field_Initialise(CellMLIntermediateField,Err)
!  CALL cmfe_CellML_IntermediateFieldCreateStart(CellML,CellMLIntermediateFieldUserNumber,CellMLIntermediateField,Err)
!  CALL cmfe_CellML_IntermediateFieldCreateFinish(CellML,Err)
  
  !Create the CellML parameters field
  CALL cmfe_Field_Initialise(CellMLParametersField,Err)
  CALL cmfe_CellML_ParametersFieldCreateStart(CellML,CellMLParametersFieldUserNumber,CellMLParametersField,Err)
  CALL cmfe_CellML_ParametersFieldCreateFinish(CellML,Err)
  
  !--------------------------------------------------------------------------------------------------------------------------------
  !Define the problem
  CALL cmfe_Problem_Initialise(Problem,Err)
  CALL cmfe_Problem_CreateStart(ProblemUserNumber,[CMFE_PROBLEM_MULTI_PHYSICS_CLASS, &
   & CMFE_PROBLEM_BIOELECTRIC_FINITE_ELASTICITY_TYPE,CMFE_PROBLEM_MONODOMAIN_1D3D_ACTIVE_STRAIN_SUBTYPE],Problem,Err)
!  CALL cmfe_Problem_SpecificationSet(Problem,CMFE_PROBLEM_MULTI_PHYSICS_CLASS,CMFE_PROBLEM_BIOELECTRIC_FINITE_ELASTICITY_TYPE, &
!   & CMFE_PROBLEM_MONODOMAIN_1D3D_ACTIVE_STRAIN_SUBTYPE,Err)
  CALL cmfe_Problem_CreateFinish(Problem,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the problem control loop
  CALL cmfe_Problem_ControlLoopCreateStart(Problem,Err)

  !set the main control loop (time loop type)
  CALL cmfe_ControlLoop_Initialise(ControlLoopMain,Err)
  CALL cmfe_Problem_ControlLoopGet(Problem,CMFE_CONTROL_LOOP_NODE,ControlLoopMain,Err)
  CALL cmfe_ControlLoop_LabelSet(ControlLoopMain,'MAIN_TIME_LOOP',Err)
  !Loop in time for STIM_STOP with the Stimulus applied.
  CALL cmfe_ControlLoop_TimesSet(ControlLoopMain,0.0_CMISSRP,ELASTICITY_TIME_STEP,ELASTICITY_TIME_STEP,Err)
  CALL cmfe_ControlLoop_TimeOutputSet(ControlLoopMain,OUTPUT_FREQUENCY,Err)
  CALL cmfe_ControlLoop_OutputTypeSet(ControlLoopMain,CMFE_CONTROL_LOOP_TIMING_OUTPUT,Err) !DO NOT CHANGE!!!

  !set the monodomain loop (time loop type)
  CALL cmfe_ControlLoop_Initialise(ControlLoopM,Err)
  CALL cmfe_Problem_ControlLoopGet(Problem,[ControlLoopMonodomainNumber,CMFE_CONTROL_LOOP_NODE],ControlLoopM,Err)
  CALL cmfe_ControlLoop_LabelSet(ControlLoopM,'MONODOMAIN_TIME_LOOP',Err)
  CALL cmfe_ControlLoop_TimesSet(ControlLoopM,0.0_CMISSRP,ELASTICITY_TIME_STEP,PDE_TIME_STEP,Err)
  CALL cmfe_ControlLoop_OutputTypeSet(ControlLoopM,CMFE_CONTROL_LOOP_NO_OUTPUT,Err)

  !set the finite elasticity loop (simple type)
  CALL cmfe_ControlLoop_Initialise(ControlLoopFE,Err)
  CALL cmfe_Problem_ControlLoopGet(Problem,[ControlLoopElasticityNumber,CMFE_CONTROL_LOOP_NODE],ControlLoopFE,Err)
  CALL cmfe_ControlLoop_TypeSet(ControlLoopFE,CMFE_PROBLEM_CONTROL_LOAD_INCREMENT_LOOP_TYPE,Err)
  CALL cmfe_ControlLoop_MaximumIterationsSet(ControlLoopFE,20,Err)
  CALL cmfe_ControlLoop_LabelSet(ControlLoopFE,'ELASTICITY_LOOP',Err)

  CALL cmfe_Problem_ControlLoopCreateFinish(Problem,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the problem solvers
  CALL cmfe_Problem_SolversCreateStart(Problem,Err)

  !Create the DAE solver
  CALL cmfe_Solver_Initialise(SolverDAE,Err)
  CALL cmfe_Problem_SolverGet(Problem,[ControlLoopMonodomainNumber,CMFE_CONTROL_LOOP_NODE], &
   & SolverDAEIndex,SolverDAE,Err)
  CALL cmfe_Solver_DAETimeStepSet(SolverDAE,ODE_TIME_STEP,Err)
  !> \todo - solve the CellML equations on the GPU for efficiency (later)
  !CALL cmfe_Solver_DAESolverTypeSet(SolverDAE,CMFE_SOLVER_DAE_EXTERNAL,Err) 
  CALL cmfe_Solver_OutputTypeSet(SolverDAE,CMFE_SOLVER_NO_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverDAE,CMFE_SOLVER_PROGRESS_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverDAE,CMFE_SOLVER_TIMING_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverDAE,CMFE_SOLVER_SOLVER_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverDAE,CMFE_SOLVER_MATRIX_OUTPUT,Err)

  !Create the parabolic solver
  CALL cmfe_Solver_Initialise(SolverParabolic,Err)
  CALL cmfe_Problem_SolverGet(Problem,[ControlLoopMonodomainNumber,CMFE_CONTROL_LOOP_NODE], &
   & SolverParabolicIndex,SolverParabolic,Err)
  CALL cmfe_Solver_DynamicSchemeSet(SolverParabolic,CMFE_SOLVER_DYNAMIC_BACKWARD_EULER_SCHEME,Err)
  CALL cmfe_Solver_OutputTypeSet(SolverParabolic,CMFE_SOLVER_NO_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverParabolic,CMFE_SOLVER_PROGRESS_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverParabolic,CMFE_SOLVER_TIMING_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverParabolic,CMFE_SOLVER_SOLVER_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverParabolic,CMFE_SOLVER_MATRIX_OUTPUT,Err)

  !Create the Finte Elasticity solver
  CALL cmfe_Solver_Initialise(SolverFE,Err)
  CALL cmfe_Solver_Initialise(LinearSolverFE,Err)
  CALL cmfe_Problem_SolverGet(Problem,[ControlLoopElasticityNumber,CMFE_CONTROL_LOOP_NODE], &
   & SolverFEIndex,SolverFE,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverFE,CMFE_SOLVER_NO_OUTPUT,Err)
  CALL cmfe_Solver_OutputTypeSet(SolverFE,CMFE_SOLVER_PROGRESS_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverFE,CMFE_SOLVER_TIMING_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverFE,CMFE_SOLVER_SOLVER_OUTPUT,Err)
  !CALL cmfe_Solver_OutputTypeSet(SolverFE,CMFE_SOLVER_MATRIX_OUTPUT,Err)
  CALL cmfe_Solver_NewtonJacobianCalculationTypeSet(SolverFE,CMFE_SOLVER_NEWTON_JACOBIAN_FD_CALCULATED,Err)
!  CALL cmfe_Solver_NewtonJacobianCalculationTypeSet(SolverFE,CMFE_SOLVER_NEWTON_JACOBIAN_EQUATIONS_CALCULATED,Err) ! 721 steps
  CALL cmfe_Solver_NewtonMaximumIterationsSet(SolverFE,500,Err)
  CALL cmfe_Solver_NewtonAbsoluteToleranceSet(SolverFE,1.E-8_CMISSRP,Err)
  CALL cmfe_Solver_NewtonSolutionToleranceSet(SolverFE,1.E-8_CMISSRP,Err)
  CALL cmfe_Solver_NewtonRelativeToleranceSet(SolverFE,1.E-8_CMISSRP,Err)
  CALL cmfe_Solver_NewtonLinearSolverGet(SolverFE,LinearSolverFE,Err)
  CALL cmfe_Solver_LinearTypeSet(LinearSolverFE,CMFE_SOLVER_LINEAR_DIRECT_SOLVE_TYPE,Err)
!  CALL cmfe_Solver_LinearTypeSet(LinearSolverFE,CMFE_SOLVER_LINEAR_ITERATIVE_SOLVE_TYPE,Err)

  CALL cmfe_Problem_SolversCreateFinish(Problem,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the problem solver CellML equations
  CALL cmfe_Problem_CellMLEquationsCreateStart(Problem,Err)

  CALL cmfe_Solver_Initialise(SolverDAE,Err)
  CALL cmfe_CellMLEquations_Initialise(CellMLEquations,Err)
  CALL cmfe_Problem_SolverGet(Problem,[ControlLoopMonodomainNumber,CMFE_CONTROL_LOOP_NODE],SolverDAEIndex,SolverDAE,Err)
  CALL cmfe_Solver_CellMLEquationsGet(SolverDAE,CellMLEquations,Err)
  CALL cmfe_CellMLEquations_CellMLAdd(CellMLEquations,CellML,CellMLIndex,Err)

  CALL cmfe_Problem_CellMLEquationsCreateFinish(Problem,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Create the problem solver equations
  CALL cmfe_Problem_SolverEquationsCreateStart(Problem,Err)

  !Create the problem solver parabolic equations (Monodomain)
  CALL cmfe_Solver_Initialise(SolverParabolic,Err)
  CALL cmfe_SolverEquations_Initialise(SolverEquationsM,Err)
  CALL cmfe_Problem_SolverGet(Problem,[ControlLoopMonodomainNumber,CMFE_CONTROL_LOOP_NODE], &
   & SolverParabolicIndex,SolverParabolic,Err)
  CALL cmfe_Solver_SolverEquationsGet(SolverParabolic,SolverEquationsM,Err)
  CALL cmfe_SolverEquations_SparsityTypeSet(SolverEquationsM,CMFE_SOLVER_SPARSE_MATRICES,Err)
  !CALL cmfe_SolverEquations_SparsityTypeSet(SolverEquationsM,CMFE_SOLVER_FULL_MATRICES,Err)  
  CALL cmfe_SolverEquations_EquationsSetAdd(SolverEquationsM,EquationsSetM,EquationsSetIndexM,Err)

  !Create the problem solver Finite Elasticity equations
  CALL cmfe_Solver_Initialise(SolverFE,Err)
  CALL cmfe_SolverEquations_Initialise(SolverEquationsFE,Err)
  CALL cmfe_Problem_SolverGet(Problem,[ControlLoopElasticityNumber,CMFE_CONTROL_LOOP_NODE],SolverFEIndex,SolverFE,Err)
  CALL cmfe_Solver_SolverEquationsGet(SolverFE,SolverEquationsFE,Err)
  CALL cmfe_SolverEquations_SparsityTypeSet(SolverEquationsFE,CMFE_SOLVER_SPARSE_MATRICES,Err)
  !CALL cmfe_SolverEquations_SparsityTypeSet(SolverEquationsFE,CMFE_SOLVER_FULL_MATRICES,Err)  
  CALL cmfe_SolverEquations_EquationsSetAdd(SolverEquationsFE,EquationsSetFE,EquationsSetIndexFE,Err)

  CALL cmfe_Problem_SolverEquationsCreateFinish(Problem,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !boundary conditions

  !Prescribe boundary conditions for monodomain
  CALL cmfe_BoundaryConditions_Initialise(BoundaryConditionsM,Err)
  CALL cmfe_SolverEquations_BoundaryConditionsCreateStart(SolverEquationsM,BoundaryConditionsM,Err)
  CALL cmfe_SolverEquations_BoundaryConditionsCreateFinish(SolverEquationsM,Err)

  !Prescribe boundary conditions for Finite Elasticity (absolute nodal parameters)
  CALL cmfe_BoundaryConditions_Initialise(BoundaryConditionsFE,Err)
  CALL cmfe_SolverEquations_BoundaryConditionsCreateStart(SolverEquationsFE,BoundaryConditionsFE,Err)

  CALL cmfe_GeneratedMesh_SurfaceGet(GeneratedMesh,CMFE_GENERATED_MESH_REGULAR_BOTTOM_SURFACE,BottomSurfaceNodes,BottomNormalXi, &
    & Err)
  CALL cmfe_GeneratedMesh_SurfaceGet(GeneratedMesh,CMFE_GENERATED_MESH_REGULAR_LEFT_SURFACE,LeftSurfaceNodes,LeftNormalXi,Err)
  CALL cmfe_GeneratedMesh_SurfaceGet(GeneratedMesh,CMFE_GENERATED_MESH_REGULAR_RIGHT_SURFACE,RightSurfaceNodes,RightNormalXi,Err)
  CALL cmfe_GeneratedMesh_SurfaceGet(GeneratedMesh,CMFE_GENERATED_MESH_REGULAR_FRONT_SURFACE,FrontSurfaceNodes,FrontNormalXi,Err)

  !Set x=0 nodes to no x displacment in x. Set x=WIDTH nodes to 100% x displacement
  DO node_idx=1,SIZE(LeftSurfaceNodes,1)
    NodeNumber=LeftSurfaceNodes(node_idx)
    CALL cmfe_Decomposition_NodeDomainGet(DecompositionFE,NodeNumber,1,NodeDomain,Err)
    IF(NodeDomain==ComputationalNodeNumber) THEN
      CALL cmfe_BoundaryConditions_SetNode(BoundaryConditionsFE,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,1,NodeNumber,1, &
!        & CMFE_BOUNDARY_CONDITION_FIXED_USER_CONTROLLED,0.0_CMISSRP,Err)
        & CMFE_BOUNDARY_CONDITION_FIXED,0.0_CMISSRP,Err)
    ENDIF
  ENDDO

  DO node_idx=1,SIZE(RightSurfaceNodes,1)
    NodeNumber=RightSurfaceNodes(node_idx)
    CALL cmfe_Decomposition_NodeDomainGet(DecompositionFE,NodeNumber,1,NodeDomain,Err)
    IF(NodeDomain==ComputationalNodeNumber) THEN
      CALL cmfe_BoundaryConditions_SetNode(BoundaryConditionsFE,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,1,NodeNumber,1, &
        & CMFE_BOUNDARY_CONDITION_FIXED_INCREMENTED,LENGTH*INITIAL_STRETCH,Err)
    ENDIF
  ENDDO

  !Set y=0 nodes to no y displacement
  DO node_idx=1,SIZE(FrontSurfaceNodes,1)
    NodeNumber=FrontSurfaceNodes(node_idx)
    CALL cmfe_Decomposition_NodeDomainGet(DecompositionFE,NodeNumber,1,NodeDomain,Err)
    IF(NodeDomain==ComputationalNodeNumber) THEN
      CALL cmfe_BoundaryConditions_SetNode(BoundaryConditionsFE,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,1,NodeNumber,2, &
        & CMFE_BOUNDARY_CONDITION_FIXED,0.0_CMISSRP,Err)
    ENDIF
  ENDDO

  !Set z=0 nodes to no z displacement
  DO node_idx=1,SIZE(BottomSurfaceNodes,1)
    NodeNumber=BottomSurfaceNodes(node_idx)
    CALL cmfe_Decomposition_NodeDomainGet(DecompositionFE,NodeNumber,1,NodeDomain,Err)
    IF(NodeDomain==ComputationalNodeNumber) THEN
      CALL cmfe_BoundaryConditions_SetNode(BoundaryConditionsFE,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,1,NodeNumber,3, &
        & CMFE_BOUNDARY_CONDITION_FIXED,0.0_CMISSRP,Err)
    ENDIF
  ENDDO

  CALL cmfe_SolverEquations_BoundaryConditionsCreateFinish(SolverEquationsFE,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Calculate the bioelectrics geometric field 
  CALL cmfe_ControlLoop_Initialise(ControlLoopM,Err)
  CALL cmfe_Problem_ControlLoopGet(Problem,[ControlLoopMonodomainNumber,CMFE_CONTROL_LOOP_NODE],ControlLoopM,Err)
  CALL cmfe_BioelectricsFiniteElasticity_UpdateGeometricField(ControlLoopM,.TRUE.,Err)

  !reset the relative contraction velocity to 0
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3, &
   & 0.0_CMISSRP,Err)

  EXPORT_FIELD=.TRUE.
  IF(EXPORT_FIELD) THEN
    CALL cmfe_Fields_Initialise(Fields,Err)
    CALL cmfe_Fields_Create(RegionM,Fields,Err)
    CALL cmfe_Fields_NodesExport(Fields,"EMGExample_M","FORTRAN",Err)
    CALL cmfe_Fields_ElementsExport(Fields,"EMGExample_M","FORTRAN",Err)
    CALL cmfe_Fields_Finalise(Fields,Err)

    CALL cmfe_Fields_Initialise(Fields,Err)
    CALL cmfe_Fields_Create(RegionFE,Fields,Err)
    CALL cmfe_Fields_NodesExport(Fields,"EMGExample_FE","FORTRAN",Err)
    CALL cmfe_Fields_ElementsExport(Fields,"EMGExample_FE","FORTRAN",Err)
    CALL cmfe_Fields_Finalise(Fields,Err)
  ENDIF



  !--------------------------------------------------------------------------------------------------------------------------------
  !Solve the problem


  !Solve the problem -- bring to new length before applying the stimulus
  WRITE(*,'(A)') "Start solve before stimulation"
  CALL cmfe_Problem_Solve(Problem,Err)

  !reset the relative contraction velocity to 0
  CALL cmfe_Field_ComponentValuesInitialise(IndependentFieldM,CMFE_FIELD_U2_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,3, &
   & 0.0_CMISSRP,Err)

  CALL cmfe_ControlLoop_Initialise(ControlLoopFE,Err)
  CALL cmfe_Problem_ControlLoopGet(Problem,[ControlLoopElasticityNumber,CMFE_CONTROL_LOOP_NODE],ControlLoopFE,Err)
  CALL cmfe_ControlLoop_MaximumIterationsSet(ControlLoopFE,1,Err)

! no change for BCs -- fix at this length!!!




  !Set the Stimulus for monodomain at the middle of the fibres
!  CALL cmfe_CellML_FieldComponentGet(CellML,shortenModelIndex,CMFE_CELLML_PARAMETERS_FIELD, &
!   & "Aliev_Panfilov/I_HH",stimcomponent,Err)


  !--------------------------------------------------------------------------------------------------------------------------------
  !Read in the MU firing times
  open(unit=5,file="input/MU_firing_times_10s.txt",action="read",iostat=stat)
  do i=1,10000
    read(5,*,iostat=stat) FIRING_TIMES(i,:)
  enddo
  close(unit=5)
  write(*,*) "Finished reading file: input/MU_firing_times_10s.txt"
  
  ! Gaussian distribution with mean 0 and std 2 (MATLAB: k = 2*randn(len,1), kk = int64(k);)
  ALLOCATE(IZ_offset(NumberOfFibres))
  open(unit=6,file="input/innervation_zone_4050.txt",action="read",iostat=stat)
  read(6,*,iostat=stat) IZ_offset(:)
  close(unit=6)
  write(*,*) "Finished reading file: input/innervation_zone_4050.txt"

!    integer :: unit, i, n
!    real, allocatable :: data(:,:)
!    unit = 20
!    open(unit,"foo.txt",status="old",action="read")
!    n = 0
!    do
!        read(unit,*,end=1)
!        n = n+1
!    end do
!    1 rewind(unit)
!    allocate(data(n,3))
!    do i = 1, n
!        read(unit,*) data(i,:)
!    end do
!    close(unit)


  !--------------------------------------------------------------------------------------------------------------------------------
  !--------------------------------------------------------------------------------------------------------------------------------
  time = 0.0_CMISSRP 
  VALUE = 0.0_CMISSRP 
  k=1
  m=1
  do while(time <= TIME_STOP)

  !--------------------------------------------------------------------------------------------------------------------------------
  !Set the Stimulus for monodomain at the middle of the fibres
  CALL cmfe_CellML_FieldComponentGet(CellML,shortenModelIndex,CMFE_CELLML_PARAMETERS_FIELD, &
   & "Aliev_Panfilov/I_HH",stimcomponent,Err)


!  VALUE = VALUE-ABS(Vmax)/20.0_CMISSRP*STIM_STOP
!!  VALUE = VALUE+ABS(Vmax)/10.0_CMISSRP*STIM_STOP
!  CALL cmfe_ControlLoop_BoundaryConditionUpdate(ControlLoopFE,1,1,VALUE,Err)
!  DO node_idx=1,SIZE(LeftSurfaceNodes,1)
!    NodeNumber=LeftSurfaceNodes(node_idx)
!    CALL cmfe_Decomposition_NodeDomainGet(DecompositionFE,NodeNumber,1,NodeDomain,Err)
!    IF(NodeDomain==ComputationalNodeNumber) THEN
!      CALL cmfe_BoundaryConditions_SetNode(BoundaryConditionsFE,DependentFieldFE,CMFE_FIELD_U_VARIABLE_TYPE,1,1,NodeNumber,1, &
!        & CMFE_BOUNDARY_CONDITION_FIXED,VALUE,Err)
!    ENDIF
!  ENDDO


  NodeNumber=(NumberOfNodesPerFibre+1)/2
  !loop over all neuromuscular junctions (middle point of the fibres)
  DO WHILE(NodeNumber<NumberOfNodesM)
    CALL cmfe_Decomposition_NodeDomainGet(DecompositionM,NodeNumber+IZ_offset(m),1,NodeDomain,Err)
    IF(NodeDomain==ComputationalNodeNumber) THEN
      CALL cmfe_Field_ParameterSetGetNode(IndependentFieldM,CMFE_FIELD_V_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,1, &
       & NodeNumber+IZ_offset(m),1,mu_nr,Err)
      if((mu_nr.LE.0).OR.(mu_nr.GE.101)) then
        mu_nr=101
      else
        val=FIRING_TIMES(k,mu_nr)
        if(val==1) then
          CALL cmfe_Field_ParameterSetUpdateNode(CellMLParametersField, &
            & CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,1,NodeNumber+IZ_offset(m),stimcomponent,STIM_VALUE,Err)
        endif
      endif
    ENDIF
    NodeNumber=NodeNumber+NumberOfNodesPerFibre
    m=m+1
  ENDDO
  m=m-NumberOfFibres


  !--------------------------------------------------------------------------------------------------------------------------------
  !Solve the problem for the stimulation time
  CALL cmfe_ControlLoop_TimesSet(ControlLoopMain,time,time+STIM_STOP,ELASTICITY_TIME_STEP,Err)
  CALL cmfe_Problem_Solve(Problem,Err)


  !--------------------------------------------------------------------------------------------------------------------------------
  !Now turn the stimulus off
  NodeNumber=(NumberOfNodesPerFibre+1)/2
  DO WHILE(NodeNumber<NumberOfNodesM)
    CALL cmfe_Decomposition_NodeDomainGet(DecompositionM,NodeNumber+IZ_offset(m),1,NodeDomain,Err)
    IF(NodeDomain==ComputationalNodeNumber) CALL cmfe_Field_ParameterSetUpdateNode(CellMLParametersField, & 
     & CMFE_FIELD_U_VARIABLE_TYPE,CMFE_FIELD_VALUES_SET_TYPE,1,1,NodeNumber+IZ_offset(m),stimcomponent,0.0_CMISSRP,Err)
    NodeNumber = NodeNumber+NumberOfNodesPerFibre
    m=m+1
  ENDDO
  m=m-NumberOfFibres

  !--------------------------------------------------------------------------------------------------------------------------------
  !Solve the problem for the rest of the period
  CALL cmfe_ControlLoop_TimesSet(ControlLoopMain,time+STIM_STOP,time+PERIODD,ELASTICITY_TIME_STEP,Err)
  CALL cmfe_Problem_Solve(Problem,Err)

  !--------------------------------------------------------------------------------------------------------------------------------
  time = time + PERIODD
  k=k+1

  end do
  !--------------------------------------------------------------------------------------------------------------------------------
  !--------------------------------------------------------------------------------------------------------------------------------


  
  !--------------------------------------------------------------------------------------------------------------------------------
!  EXPORT_FIELD=.TRUE.
  IF(EXPORT_FIELD) THEN
    CALL cmfe_Fields_Initialise(Fields,Err)
    CALL cmfe_Fields_Create(RegionM,Fields,Err)
    CALL cmfe_Fields_NodesExport(Fields,"EMGExample_M","FORTRAN",Err)
    CALL cmfe_Fields_ElementsExport(Fields,"EMGExample_M","FORTRAN",Err)
    CALL cmfe_Fields_Finalise(Fields,Err)

    CALL cmfe_Fields_Initialise(Fields,Err)
    CALL cmfe_Fields_Create(RegionFE,Fields,Err)
    CALL cmfe_Fields_NodesExport(Fields,"EMGExample_FE","FORTRAN",Err)
    CALL cmfe_Fields_ElementsExport(Fields,"EMGExample_FE","FORTRAN",Err)
    CALL cmfe_Fields_Finalise(Fields,Err)
  ENDIF
  
  !--------------------------------------------------------------------------------------------------------------------------------
  !Finialise CMISS
  CALL cmfe_Finalise(Err)

  WRITE(*,'(A)') "Program successfully completed."

  if(NumberOfComputationalNodes==1) then
    open(unit=888,file="times.out",iostat=stat)
    write(888,*) 'single processor'
!!! time elapsed
    total = etime(elapsed)
    write(888,*) 'End: total=', total, ' user=', elapsed(1), ' system=', elapsed(2)
!!!
    close(unit=888)
  else
    open(unit=888,file="times.out",iostat=stat,access='append')
    write(888,*) 'two processors'
!!! time elapsed
    total = etime(elapsed)
    write(888,*) 'End: total=', total, ' user=', elapsed(1), ' system=', elapsed(2)
!!!
    close(unit=888)
  endif
  
  STOP

END PROGRAM LARGEUNIAXIALEXTENSIONEXAMPLE


