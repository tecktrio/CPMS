import { ProductionAssignment } from '../../database/schemas/production-assignment.schema';

type AssignmentProgress = Pick<ProductionAssignment,
  'status' | 'assigned_cartons' | 'completed_cartons' | 'production_done'>;

export function isAssignmentProductionDone(assignment: AssignmentProgress): boolean {
  return assignment.assigned_cartons > 0 &&
    assignment.completed_cartons >= assignment.assigned_cartons &&
    (assignment.production_done === true ||
      (assignment.production_done === undefined && assignment.status === 'COMPLETED'));
}

export function isItemProductionDone(assignments: AssignmentProgress[]): boolean {
  const active = assignments.filter((assignment) => assignment.status !== 'CANCELLED');
  return active.length > 0 && active.every(isAssignmentProductionDone);
}
