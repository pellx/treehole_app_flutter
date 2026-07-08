import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('users')
export class UserEntity {
  @PrimaryGeneratedColumn()
  user_id: number;

  @Column({ type: 'varchar', length: 100, nullable: true, default: null })
  user_display_id: string;

  @Index('idx_external_token')
  @Index('uk_external_token', { unique: true })
  @Column({ type: 'varchar', length: 128, nullable: true, default: null })
  user_external_token: string;

  @Column({ type: 'timestamp', nullable: true, default: null })
  user_display_id_changed_at: Date;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
