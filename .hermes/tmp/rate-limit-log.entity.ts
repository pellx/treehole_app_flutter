import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('rate_limit_log')
@Index('idx_subject_action_time', ['subject_type', 'subject_id', 'action', 'created_at'])
export class RateLimitLogEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 10 })
  subject_type: string;

  @Column({ type: 'varchar', length: 64 })
  subject_id: string;

  @Column({ type: 'varchar', length: 30 })
  action: string;

  @CreateDateColumn()
  created_at: Date;
}
