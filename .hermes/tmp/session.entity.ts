import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('sessions')
export class SessionEntity {
  @PrimaryGeneratedColumn()
  session_id: number;

  @Column({ type: 'varchar', length: 128 })
  session_secret_hash: string;

  @Index('idx_user_id')
  @Column({ type: 'int' })
  user_id: number;

  @Index('idx_device_id')
  @Column({ type: 'int' })
  device_id: number;

  @Column({ type: 'timestamp' })
  expires_at: Date;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
